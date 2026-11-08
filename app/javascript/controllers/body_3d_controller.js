import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"
import { OrbitControls } from "three/addons/controls/OrbitControls.js"
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js"

// Carga el modelo anatómico de public/anatomy_study.glb y lo divide por zonas
// (cabeza, tórax, abdomen y extremidades) para colorearlas según el estado.
// Si el GLB falla, se usa el cuerpo procedural low-poly como respaldo.
const MODEL_URL = "/anatomy_study.glb"
const MODEL_HEIGHT = 2.9
const MODEL_CENTER_Y = 0.45
const ZONE_ORDER = ["head", "chest", "abdomen", "limbs"]

const STATUS_COLORS = {
  green: 0x22c55e,
  yellow: 0xf59e0b,
  red: 0xef4444,
  unknown: 0x64748b
}

const ALERT_CLASSES = {
  red: ["ring-2", "ring-rose-500/40", "shadow-[0_0_90px_-30px_rgba(244,63,94,0.6)]"],
  yellow: ["ring-1", "ring-amber-500/30", "shadow-[0_0_70px_-30px_rgba(245,158,11,0.45)]"],
  green: []
}

const ALL_ALERT_CLASSES = Object.values(ALERT_CLASSES).flat()

const ZONE_LABELS = {
  head: "Cabeza",
  chest: "Tórax",
  abdomen: "Abdomen",
  limbs: "Extremidades"
}

const STATUS_LABELS = {
  green: "Normal",
  yellow: "Vigilar",
  red: "Crítico",
  unknown: "Sin datos"
}

export default class extends Controller {
  static targets = ["canvas", "panel", "overall", "points", "loader", "alert"]
  static values = { url: { type: String, default: "/api/health_status" } }

  connect() {
    this.snapshot = null
    this.selectedZone = null
    this.zoneMaterials = {}
    this.zoneGroups = {}
    this.zoneCenters = {}
    this.marker = null
    this.pointerStart = null

    this.setupScene()
    this.setupRaycaster()
    this.setupResize()
    this.onReadingCreated = () => this.loadStatus()
    document.addEventListener("health:reading-created", this.onReadingCreated)

    this.animate = this.animate.bind(this)
    this.animationId = requestAnimationFrame(this.animate)

    this.loadStatus()
    this.loadAnatomyModel()
  }

  disconnect() {
    document.removeEventListener("health:reading-created", this.onReadingCreated)
    cancelAnimationFrame(this.animationId)
    this.resizeObserver?.disconnect()
    this.controls?.dispose()
    this.disposeBody()
    this.renderer?.dispose()
    this.renderer?.domElement?.remove()
  }

  // ---------------------------------------------------------------------------
  // Escena Three.js
  // ---------------------------------------------------------------------------
  setupScene() {
    this.scene = new THREE.Scene()

    this.camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100)
    this.camera.position.set(0, 0.75, 4.6)

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.renderer.outputColorSpace = THREE.SRGBColorSpace
    this.renderer.shadowMap.enabled = true
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap
    this.renderer.domElement.className = "h-full w-full"
    this.canvasTarget.appendChild(this.renderer.domElement)

    this.controls = new OrbitControls(this.camera, this.renderer.domElement)
    this.controls.target.set(0, 0.6, 0)
    this.controls.enableDamping = true
    this.controls.dampingFactor = 0.08
    this.controls.minDistance = 2.4
    this.controls.maxDistance = 7.5
    this.controls.maxPolarAngle = Math.PI * 0.58
    this.controls.update()

    // Iluminación: luz frontal/superior con sombras suaves + relleno lateral.
    this.scene.add(new THREE.AmbientLight(0x94a3b8, 0.45))

    const key = new THREE.DirectionalLight(0xf8fafc, 2.6)
    key.position.set(2.6, 6, 5)
    key.castShadow = true
    key.shadow.mapSize.set(1024, 1024)
    key.shadow.camera.near = 0.5
    key.shadow.camera.far = 20
    key.shadow.camera.left = -2.5
    key.shadow.camera.right = 2.5
    key.shadow.camera.top = 3.5
    key.shadow.camera.bottom = -3
    key.shadow.bias = -0.0004
    key.shadow.normalBias = 0.02
    key.shadow.radius = 3
    key.target.position.set(0, 0.5, 0)
    this.scene.add(key)
    this.scene.add(key.target)

    const front = new THREE.DirectionalLight(0xffffff, 0.9)
    front.position.set(0, 3.5, 6)
    this.scene.add(front)

    const fill = new THREE.DirectionalLight(0x38bdf8, 1.0)
    fill.position.set(-4, 2.5, 3)
    this.scene.add(fill)

    const rim = new THREE.DirectionalLight(0xf472b6, 0.85)
    rim.position.set(0, 4, -4)
    this.scene.add(rim)

    // Plataforma de referencia.
    const platform = new THREE.Mesh(
      new THREE.CylinderGeometry(1.15, 1.3, 0.08, 48),
      new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.7, metalness: 0.5 })
    )
    platform.position.y = -1.05
    platform.receiveShadow = true
    this.scene.add(platform)

    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(1.22, 0.012, 12, 80),
      new THREE.MeshBasicMaterial({ color: 0x22d3ee, transparent: true, opacity: 0.55 })
    )
    ring.rotation.x = Math.PI / 2
    ring.position.y = -1.0
    this.scene.add(ring)
  }

  // Asigna un material independiente por zona para poder cambiar su color.
  zoneMaterial(zone) {
    if (!this.zoneMaterials[zone]) {
      this.zoneMaterials[zone] = new THREE.MeshStandardMaterial({
        color: STATUS_COLORS.unknown,
        emissive: new THREE.Color(STATUS_COLORS.unknown),
        emissiveIntensity: 0.18,
        roughness: 0.45,
        metalness: 0.25
      })
    }
    return this.zoneMaterials[zone]
  }

  addPart(group, geometry, zone, position, rotation = [0, 0, 0]) {
    const mesh = new THREE.Mesh(geometry, this.zoneMaterial(zone))
    mesh.position.set(...position)
    mesh.rotation.set(...rotation)
    mesh.userData.zone = zone
    mesh.castShadow = true
    mesh.receiveShadow = true
    group.add(mesh)
    return mesh
  }

  async loadAnatomyModel() {
    try {
      const gltf = await new GLTFLoader().loadAsync(MODEL_URL)
      this.buildBodyFromGLTF(gltf.scene)
    } catch (error) {
      console.error("No se pudo cargar el modelo anatómico; se usa el placeholder", error)
      this.buildPlaceholderBody()
    } finally {
      if (this.hasLoaderTarget) this.loaderTarget.remove()
    }
  }

  buildBodyFromGLTF(source) {
    this.disposeBody()

    const body = new THREE.Group()
    this.scene.add(body)
    this.body = body
    this.zoneGroups = {}
    this.zoneMaterials = {}

    source.updateMatrixWorld(true)
    const box = new THREE.Box3().setFromObject(source)
    const size = box.getSize(new THREE.Vector3())
    const center = box.getCenter(new THREE.Vector3())
    const scale = MODEL_HEIGHT / (size.y || 1)
    const scaledWidth = size.x * scale
    const bottomY = MODEL_CENTER_Y - MODEL_HEIGHT / 2

    const buffers = {}
    ZONE_ORDER.forEach((name) => {
      buffers[name] = { positions: [], normals: [], colors: [] }
    })

    const vertex = new THREE.Vector3()
    const normal = new THREE.Vector3()
    const normalMatrix = new THREE.Matrix3()
    const points = [new THREE.Vector3(), new THREE.Vector3(), new THREE.Vector3()]
    const normals = [new THREE.Vector3(), new THREE.Vector3(), new THREE.Vector3()]
    const vertexColors = [new THREE.Color(), new THREE.Color(), new THREE.Color()]

    source.traverse((mesh) => {
      if (!mesh.isMesh) return

      const geometry = mesh.geometry
      const position = geometry.attributes.position
      if (!position) return
      const normalAttribute = geometry.attributes.normal
      const colorAttribute = geometry.attributes.color
      const index = geometry.index
      const triangleCount = index ? index.count / 3 : position.count / 3

      normalMatrix.getNormalMatrix(mesh.matrixWorld)

      for (let triangle = 0; triangle < triangleCount; triangle++) {
        for (let corner = 0; corner < 3; corner++) {
          const vertexIndex = index ? index.getX(triangle * 3 + corner) : triangle * 3 + corner

          vertex.fromBufferAttribute(position, vertexIndex).applyMatrix4(mesh.matrixWorld)
          points[corner].set(
            (vertex.x - center.x) * scale,
            (vertex.y - center.y) * scale + MODEL_CENTER_Y,
            (vertex.z - center.z) * scale
          )

          if (normalAttribute) {
            normal.fromBufferAttribute(normalAttribute, vertexIndex).applyMatrix3(normalMatrix).normalize()
            normals[corner].copy(normal)
          } else {
            normals[corner].set(0, 1, 0)
          }

          if (colorAttribute) {
            vertexColors[corner].fromBufferAttribute(colorAttribute, vertexIndex)
          } else {
            vertexColors[corner].setRGB(0.9, 0.9, 0.9)
          }
        }

        const centerX = (points[0].x + points[1].x + points[2].x) / 3
        const centerY = (points[0].y + points[1].y + points[2].y) / 3
        const zoneName = this.classifyZone(
          (centerY - bottomY) / MODEL_HEIGHT,
          Math.abs(centerX) / (scaledWidth || 1)
        )
        const target = buffers[zoneName]

        for (let corner = 0; corner < 3; corner++) {
          target.positions.push(points[corner].x, points[corner].y, points[corner].z)
          target.normals.push(normals[corner].x, normals[corner].y, normals[corner].z)
          target.colors.push(vertexColors[corner].r, vertexColors[corner].g, vertexColors[corner].b)
        }
      }

      geometry.dispose()
    })

    ZONE_ORDER.forEach((name) => {
      const data = buffers[name]
      if (!data.positions.length) return

      const geometry = new THREE.BufferGeometry()
      geometry.setAttribute("position", new THREE.Float32BufferAttribute(data.positions, 3))
      geometry.setAttribute("normal", new THREE.Float32BufferAttribute(data.normals, 3))
      geometry.setAttribute("color", new THREE.Float32BufferAttribute(data.colors, 3))
      geometry.computeBoundingSphere()

      const material = new THREE.MeshStandardMaterial({
        color: 0xffffff,
        emissive: new THREE.Color(0x000000),
        emissiveIntensity: 0,
        vertexColors: true,
        roughness: 0.58,
        metalness: 0.06,
        side: THREE.DoubleSide
      })
      material.userData.naturalColors = true

      geometry.computeBoundingBox()
      this.zoneCenters[name] = geometry.boundingBox.getCenter(new THREE.Vector3())

      const mesh = new THREE.Mesh(geometry, material)
      mesh.userData.zone = name
      mesh.castShadow = true
      mesh.receiveShadow = true
      body.add(mesh)
      this.zoneGroups[name] = mesh
      this.zoneMaterials[name] = material
    })

    this.applyStatuses()
    if (this.selectedZone) this.showSelectionMarker(this.selectedZone.name)
  }

  classifyZone(verticalRatio, horizontalRatio) {
    if (verticalRatio >= 0.86) return "head"
    if (verticalRatio >= 0.63) return horizontalRatio > 0.27 ? "limbs" : "chest"
    if (verticalRatio >= 0.44) return horizontalRatio > 0.28 ? "limbs" : "abdomen"
    return "limbs"
  }

  disposeBody() {
    if (this.marker) {
      this.marker.traverse((child) => {
        if (child.isMesh) {
          child.geometry.dispose()
          child.material.dispose()
        }
      })
      this.scene.remove(this.marker)
      this.marker = null
    }
    this.zoneCenters = {}

    if (!this.body) return

    this.body.traverse((child) => {
      if (child.isMesh) child.geometry.dispose()
    })
    Object.values(this.zoneMaterials).forEach((material) => material.dispose())
    this.scene.remove(this.body)
    this.body = null
    this.zoneGroups = {}
    this.zoneMaterials = {}
  }

  ensureSelectionMarker() {
    if (this.marker) return this.marker

    const marker = new THREE.Group()
    const ring = new THREE.Mesh(
      new THREE.RingGeometry(0.052, 0.073, 40),
      new THREE.MeshBasicMaterial({
        color: 0x22d3ee,
        transparent: true,
        opacity: 0.95,
        side: THREE.DoubleSide,
        depthTest: false,
        depthWrite: false
      })
    )
    const dot = new THREE.Mesh(
      new THREE.CircleGeometry(0.011, 24),
      new THREE.MeshBasicMaterial({
        color: 0xffffff,
        transparent: true,
        opacity: 0.95,
        side: THREE.DoubleSide,
        depthTest: false,
        depthWrite: false
      })
    )
    ring.renderOrder = 20
    dot.renderOrder = 21
    marker.add(ring, dot)
    marker.visible = false
    this.scene.add(marker)
    this.marker = marker
    return marker
  }

  showSelectionMarker(zoneName, point = null) {
    const position = point || this.zoneCenters[zoneName]
    if (!position) return

    const marker = this.ensureSelectionMarker()
    marker.position.copy(position)
    marker.visible = true
  }

  buildPlaceholderBody() {
    const body = new THREE.Group()
    body.position.y = 0.05
    this.scene.add(body)
    this.body = body

    const zone = (name) => {
      const group = new THREE.Group()
      group.userData.zone = name
      this.zoneGroups[name] = group
      body.add(group)
      return group
    }

    // CABEZA: esfera + cuello.
    const head = zone("head")
    this.addPart(head, new THREE.SphereGeometry(0.27, 32, 24), "head", [0, 1.72, 0])
    this.addPart(head, new THREE.CylinderGeometry(0.11, 0.13, 0.18, 20), "head", [0, 1.45, 0])
    // Visor decorativo (no clickeable aparte, pertenece a la cabeza).
    const visor = new THREE.Mesh(
      new THREE.SphereGeometry(0.276, 32, 16, 0, Math.PI * 2, 0, Math.PI * 0.42),
      new THREE.MeshStandardMaterial({ color: 0x0ea5e9, transparent: true, opacity: 0.32, roughness: 0.1, metalness: 0.6 })
    )
    visor.position.set(0, 1.73, 0.02)
    visor.rotation.x = Math.PI / 2.15
    head.add(visor)

    // TÓRAX: cápsula ancha + hombros.
    const chest = zone("chest")
    this.addPart(chest, new THREE.CapsuleGeometry(0.34, 0.34, 10, 24), "chest", [0, 1.08, 0])
    this.addPart(chest, new THREE.SphereGeometry(0.17, 20, 16), "chest", [-0.4, 1.22, 0])
    this.addPart(chest, new THREE.SphereGeometry(0.17, 20, 16), "chest", [0.4, 1.22, 0])

    // ABDOMEN: cápsula más estrecha.
    const abdomen = zone("abdomen")
    this.addPart(abdomen, new THREE.CapsuleGeometry(0.28, 0.25, 10, 24), "abdomen", [0, 0.62, 0])

    // EXTREMIDADES: brazos y piernas.
    const limbs = zone("limbs")
    this.addPart(limbs, new THREE.CapsuleGeometry(0.1, 0.5, 8, 16), "limbs", [-0.47, 0.91, 0], [0, 0, 0.16])
    this.addPart(limbs, new THREE.CapsuleGeometry(0.1, 0.5, 8, 16), "limbs", [0.47, 0.91, 0], [0, 0, -0.16])
    this.addPart(limbs, new THREE.CapsuleGeometry(0.09, 0.42, 8, 16), "limbs", [-0.58, 0.42, 0], [0, 0, 0.1])
    this.addPart(limbs, new THREE.CapsuleGeometry(0.09, 0.42, 8, 16), "limbs", [0.58, 0.42, 0], [0, 0, -0.1])
    this.addPart(limbs, new THREE.CapsuleGeometry(0.13, 0.55, 10, 18), "limbs", [-0.17, -0.16, 0], [0, 0, 0.035])
    this.addPart(limbs, new THREE.CapsuleGeometry(0.13, 0.55, 10, 18), "limbs", [0.17, -0.16, 0], [0, 0, -0.035])
    this.addPart(limbs, new THREE.CapsuleGeometry(0.1, 0.35, 8, 16), "limbs", [-0.19, -0.74, 0], [0, 0, 0.02])
    this.addPart(limbs, new THREE.CapsuleGeometry(0.1, 0.35, 8, 16), "limbs", [0.19, -0.74, 0], [0, 0, -0.02])
    this.addPart(limbs, new THREE.BoxGeometry(0.2, 0.09, 0.34), "limbs", [-0.19, -0.98, 0.05])
    this.addPart(limbs, new THREE.BoxGeometry(0.2, 0.09, 0.34), "limbs", [0.19, -0.98, 0.05])
  }

  // ---------------------------------------------------------------------------
  // Interacción: Raycaster
  // ---------------------------------------------------------------------------
  setupRaycaster() {
    this.raycaster = new THREE.Raycaster()
    this.pointer = new THREE.Vector2()

    this.onPointerDown = (event) => {
      this.pointerStart = { x: event.clientX, y: event.clientY }
    }

    this.onPointerUp = (event) => {
      if (!this.pointerStart) return

      const moved = Math.hypot(event.clientX - this.pointerStart.x, event.clientY - this.pointerStart.y)
      this.pointerStart = null
      if (moved > 6) return // fue un arrastre de cámara, no un click

      const rect = this.renderer.domElement.getBoundingClientRect()
      this.pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
      this.pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1

      this.raycaster.setFromCamera(this.pointer, this.camera)
      if (!this.body) return
      const hits = this.raycaster.intersectObjects(this.body.children, true)
      const hit = hits.find((candidate) => candidate.object.userData.zone)
      if (hit) this.selectZone(hit.object.userData.zone, hit.point)
    }

    this.renderer.domElement.addEventListener("pointerdown", this.onPointerDown)
    this.renderer.domElement.addEventListener("pointerup", this.onPointerUp)
    this.renderer.domElement.style.cursor = "grab"
  }

  setupResize() {
    this.resizeObserver = new ResizeObserver(() => this.resize())
    this.resizeObserver.observe(this.canvasTarget)
    this.resize()
  }

  resize() {
    const { clientWidth: width, clientHeight: height } = this.canvasTarget
    if (!width || !height) return

    this.camera.aspect = width / height
    this.camera.updateProjectionMatrix()
    this.renderer.setSize(width, height, false)
  }

  animate() {
    this.animationId = requestAnimationFrame(this.animate)
    this.controls.update()

    if (this.marker?.visible) {
      this.marker.quaternion.copy(this.camera.quaternion)
      this.marker.scale.setScalar(1 + Math.sin(performance.now() * 0.004) * 0.08)
    }

    this.renderer.render(this.scene, this.camera)
  }

  // ---------------------------------------------------------------------------
  // Datos y pintado de estado
  // ---------------------------------------------------------------------------
  async loadStatus() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      this.snapshot = await response.json()
      this.applyStatuses()
      this.updateOverall()
      this.updatePoints()

      const zones = this.snapshot.zones || []
      const worst = zones.find((zone) => zone.status === "red") ||
                    zones.find((zone) => zone.status === "yellow") ||
                    zones.find((zone) => zone.name === "chest")
      if (worst && !this.selectedZone) this.selectZone(worst.name)
      if (this.selectedZone) this.renderZonePanel(this.selectedZone)
    } catch (error) {
      console.error("No se pudo cargar /api/health_status", error)
    }
  }

  applyStatuses() {
    const zones = this.snapshot?.zones || []

    zones.forEach((zone) => {
      const status = zone.status || "unknown"
      const material = this.zoneMaterials[zone.name]
      if (!material) return

      if (material.userData.naturalColors) {
        material.color.setHex(0xffffff)
        material.emissive.setHex(0x000000)
        material.emissiveIntensity = 0
      } else {
        const color = STATUS_COLORS[status] || STATUS_COLORS.unknown
        material.color.setHex(color)
        material.emissive.setHex(color)
        material.emissiveIntensity = 0.18
      }
    })
  }

  selectZone(zoneName, point = null) {
    this.selectedZone = (this.snapshot?.zones || []).find((zone) => zone.name === zoneName)
    this.renderZonePanel(this.selectedZone)
    this.showSelectionMarker(zoneName, point)
  }

  renderZonePanel(zone) {
    if (!this.hasPanelTarget) return
    if (!zone) return

    const indicators = zone.indicators || []
    const status = zone.status || "unknown"
    const statusClass = {
      green: "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
      yellow: "bg-amber-500/15 text-amber-300 border-amber-500/40",
      red: "bg-rose-500/15 text-rose-300 border-rose-500/40",
      unknown: "bg-slate-500/15 text-slate-300 border-slate-500/40"
    }[status]

    const statusOrder = { red: 0, yellow: 1, green: 2, unknown: 3 }
    const badgeFor = (value) => {
      return {
        green: "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
        yellow: "bg-amber-500/15 text-amber-300 border-amber-500/40",
        red: "bg-rose-500/15 text-rose-300 border-rose-500/40"
      }[value] || "bg-slate-500/15 text-slate-300 border-slate-500/40"
    }
    const alertRows = (this.snapshot?.zones || [])
      .filter((other) => other.name !== zone.name && other.status !== "green" && other.status !== "unknown")
      .sort((a, b) => (statusOrder[a.status] ?? 9) - (statusOrder[b.status] ?? 9))
      .map((other) => {
        const worst = (other.indicators || []).find((item) => item.status === other.status) || (other.indicators || [])[0]
        const detail = worst ? `${worst.label} · ${worst.value} ${worst.unit}` : "Revisar indicadores de la zona"
        return `
          <li class="flex items-start justify-between gap-2 rounded-lg border border-slate-800 bg-slate-950/50 px-2.5 py-2">
            <div class="min-w-0">
              <p class="text-xs font-medium text-slate-200">${this.escape(ZONE_LABELS[other.name] || other.name)}</p>
              <p class="mt-0.5 truncate text-[11px] text-slate-300">${this.escape(detail)}</p>
            </div>
            <span class="inline-flex shrink-0 items-center rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase ${badgeFor(other.status)}">${this.escape(STATUS_LABELS[other.status] || other.status)}</span>
          </li>
        `
      }).join("")
    const alertsBlock = alertRows ? `
      <div class="mt-4 rounded-xl border border-amber-500/25 bg-amber-500/5 p-3">
        <p class="text-[10px] font-semibold uppercase tracking-wider text-amber-200">También en alerta</p>
        <ul class="mt-2 space-y-1.5">${alertRows}</ul>
      </div>
    ` : ""

    const rows = indicators.map((indicator) => {
      const badge = {
        green: "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
        yellow: "bg-amber-500/15 text-amber-300 border-amber-500/40",
        red: "bg-rose-500/15 text-rose-300 border-rose-500/40"
      }[indicator.status] || "bg-slate-500/15 text-slate-300 border-slate-500/40"

      const recommendation = indicator.recommendation?.text || ""
      const urgency = indicator.recommendation?.urgency || "routine"

      return `
        <div class="rounded-xl border border-slate-800 bg-slate-950/60 p-3">
          <div class="flex items-start justify-between gap-2">
            <div>
              <p class="text-sm font-medium text-slate-200">${this.escape(indicator.label)}</p>
              <p class="mt-1 text-lg font-semibold text-white">${indicator.value} <span class="text-xs font-normal text-slate-400">${this.escape(indicator.unit)}</span></p>
            </div>
            <span class="inline-flex shrink-0 items-center rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase ${badge}">${this.escape(STATUS_LABELS[indicator.status] || indicator.status)}</span>
          </div>
          <p class="mt-2 text-xs leading-relaxed text-slate-300">${this.escape(recommendation)}</p>
          <p class="mt-1 text-[10px] uppercase tracking-wider ${urgency === "urgent" ? "text-rose-300" : urgency === "watch" ? "text-amber-300" : "text-slate-400"}">${urgency === "urgent" ? "Atención prioritaria" : urgency === "watch" ? "En vigilancia" : "Rutina"}</p>
        </div>
      `
    }).join("")

    // Botón SOS: solo aparece cuando la zona seleccionada está en crítico.
    const sosBlock = status === "red" ? `
      <button type="button" data-action="click->sos#open"
              class="mt-4 w-full animate-pulse rounded-xl border border-rose-500/60 bg-rose-500/20 px-4 py-2.5 text-sm font-semibold text-rose-100 shadow-lg shadow-rose-500/20 transition hover:bg-rose-500/30">
        🚨 Solicitar Telemetría Médica Prioritaria
      </button>
    ` : ""

    this.panelTarget.innerHTML = `
      <div class="flex items-start justify-between gap-3">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Zona seleccionada</p>
          <h2 class="mt-1 text-xl font-semibold text-white">${this.escape(ZONE_LABELS[zone.name] || zone.name)}</h2>
        </div>
        <span class="inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold uppercase ${statusClass}">${this.escape(STATUS_LABELS[status] || status)}</span>
      </div>
      <p class="mt-3 text-sm leading-relaxed text-slate-300">${this.escape(zone.description || "")}</p>
      <div class="mt-4 space-y-2">
        ${rows || '<p class="rounded-xl border border-dashed border-slate-700 p-3 text-sm text-slate-400">Sin mediciones para esta zona.</p>'}
      </div>
      ${alertsBlock}
      ${sosBlock}
      <button type="button" data-action="click->health-form#open"
              class="mt-4 w-full rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-cyan-400">
        Registrar nueva medición
      </button>
      <p class="mt-3 text-[11px] leading-relaxed text-slate-400">
        La recomendación es orientativa. En estado crítico, contacta al Flight Surgeon.
      </p>
    `
  }

  updateOverall() {
    if (!this.hasOverallTarget) return

    const status = this.snapshot?.overall_status || "green"
    const zones = this.snapshot?.zones || []
    const alertZones = zones.filter((zone) => zone.status === status)
    const alertNames = alertZones.map((zone) => ZONE_LABELS[zone.name] || zone.name).join(", ")
    const classes = {
      green: "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
      yellow: "bg-amber-500/15 text-amber-300 border-amber-500/40",
      red: "bg-rose-500/15 text-rose-300 border-rose-500/40"
    }
    this.overallTarget.className = `inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-medium ${classes[status] || classes.green}`
    this.overallTarget.innerHTML = `
      <span class="inline-block h-2 w-2 rounded-full ${status === "red" ? "bg-rose-400" : status === "yellow" ? "bg-amber-400" : "bg-emerald-400"}"></span>
      Estado general: <span class="font-semibold uppercase">${this.escape(STATUS_LABELS[status] || status)}</span>
      ${alertZones.length && status !== "green" ? `<span class="text-xs font-normal opacity-80">· ${status === "red" ? "zonas críticas" : "zonas en vigilancia"}: ${this.escape(alertNames)}</span>` : ""}
    `

    if (this.hasAlertTarget) {
      this.alertTarget.classList.remove(...ALL_ALERT_CLASSES)
      this.alertTarget.classList.add(...(ALERT_CLASSES[status] || []))
    }
  }

  updatePoints() {
    if (this.hasPointsTarget) {
      this.pointsTarget.textContent = this.snapshot?.astronaut?.total_points ?? 0
    }
  }

  escape(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;")
  }
}
