import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"
import { OrbitControls } from "three/addons/controls/OrbitControls.js"
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js"

// Loads the anatomy model from public/anatomy_study.glb and splits it by zone
// (head, chest, abdomen and limbs) so each region can be tinted by health status.
// If the GLB fails, a procedural low-poly body is used as a fallback.
const MODEL_URL = "/anatomy_study.glb"
const MODEL_HEIGHT = 2.9
const MODEL_CENTER_Y = 0.45
const ZONE_ORDER = ["head", "chest", "abdomen", "limbs"]
const MODEL_LOAD_TIMEOUT = 8000

const STATUS_COLORS = {
  green: 0x22c55e,
  yellow: 0xf59e0b,
  red: 0xef4444,
  unknown: 0x64748b
}

const STATUS_MARKER_COLORS = {
  green: 0x34d399,
  yellow: 0xfbbf24,
  red: 0xfb7185,
  unknown: 0x94a3b8
}

const ALERT_CLASSES = {
  red: ["ring-2", "ring-rose-500/40", "shadow-[0_0_90px_-30px_rgba(244,63,94,0.6)]"],
  yellow: ["ring-1", "ring-amber-500/30", "shadow-[0_0_70px_-30px_rgba(245,158,11,0.45)]"],
  green: []
}

const ALL_ALERT_CLASSES = Object.values(ALERT_CLASSES).flat()

const ZONE_LABELS = {
  head: "Head",
  chest: "Chest",
  abdomen: "Abdomen",
  limbs: "Limbs / Bones",
  psychological: "Psychological zone",
  immune: "Immune system"
}

const STATUS_LABELS = {
  green: "Normal",
  yellow: "Follow-up",
  red: "Medical evaluation",
  unknown: "No data"
}

const HAZARD_LABELS = {
  space_radiation: "Space radiation",
  isolation_confinement: "Isolation and confinement",
  distance_from_earth: "Distance from Earth",
  gravity_fields: "Gravity fields",
  closed_environment: "Closed environment"
}

const LABEL_DOT_CLASSES = {
  green: "bg-emerald-400",
  yellow: "bg-amber-400",
  red: "bg-rose-400",
  unknown: "bg-slate-500"
}

const LABEL_ANCHOR_OFFSETS = {
  head: [0.42, 0.16, 0],
  chest: [0.52, 0.02, 0],
  abdomen: [0.42, -0.02, 0],
  limbs: [-0.62, 0.04, 0]
}

export default class extends Controller {
  static targets = ["canvas", "panel", "overall", "points", "loader", "alert", "fallback"]
  static values = { url: { type: String, default: "/api/health_status" } }

  connect() {
    this.snapshot = null
    this.selectedZone = null
    this.zoneMaterials = {}
    this.zoneGroups = {}
    this.zoneCenters = {}
    this.marker = null
    this.zoneMarkers = null
    this.zoneMarkerMeshes = {}
    this.markerTexture = null
    this.pointerStart = null
    this.modelLoaded = false
    this.fallbackVisible = false

    this.setupScene()
    this.setupZoneLabels()
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
    clearTimeout(this.modelLoadTimer)
    this.resizeObserver?.disconnect()
    this.controls?.dispose()
    this.disposeBody()
    this.labelLayer?.remove()
    this.renderer?.dispose()
    this.renderer?.domElement?.remove()
  }

  // ---------------------------------------------------------------------------
  // Three.js scene
  // ---------------------------------------------------------------------------
  setupScene() {
    this.scene = new THREE.Scene()

    this.camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100)
    this.camera.position.set(0, 0.6, 3.4)

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

    // Lighting: soft front/top key light with shadows + lateral fill.
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

    // Reference platform.
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

  // Assigns an independent material per zone so its color can change.
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
    this.modelLoadTimer = setTimeout(() => {
      if (this.modelLoaded) return

      // Slow connection: keep the experience usable with the procedural body.
      this.buildPlaceholderBody()
      if (this.hasLoaderTarget) this.loaderTarget.remove()
    }, MODEL_LOAD_TIMEOUT)

    try {
      const gltf = await new GLTFLoader().loadAsync(MODEL_URL)
      this.modelLoaded = true
      clearTimeout(this.modelLoadTimer)
      this.buildBodyFromGLTF(gltf.scene)
    } catch (error) {
      console.error("Could not load the anatomy model; using the fallback.", error)
      if (!this.modelLoaded) this.buildPlaceholderBody()
      this.showFallback("The 3D model could not be loaded. Showing the 2D body map.")
    } finally {
      clearTimeout(this.modelLoadTimer)
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

      // Keep the original anatomical (muscle) colors from the GLB.
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
      const mesh = new THREE.Mesh(geometry, material)
      mesh.userData.zone = name
      mesh.castShadow = true
      mesh.receiveShadow = true
      body.add(mesh)
      this.zoneGroups[name] = mesh
      this.zoneMaterials[name] = material
    })

    this.refreshZoneCenters()
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

    if (this.zoneMarkers) {
      this.zoneMarkers.traverse((child) => {
        if (child.material) child.material.dispose()
      })
      this.scene.remove(this.zoneMarkers)
      this.zoneMarkers = null
      this.zoneMarkerMeshes = {}
    }
    this.markerTexture?.dispose()
    this.markerTexture = null

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

  // Persistent red/yellow/green status dots on the body (one per zone).
  ensureZoneMarkers() {
    if (this.zoneMarkers) return this.zoneMarkers

    this.zoneMarkers = new THREE.Group()
    this.zoneMarkers.renderOrder = 30
    this.scene.add(this.zoneMarkers)
    return this.zoneMarkers
  }

  createMarkerTexture() {
    const size = 128
    const canvas = document.createElement("canvas")
    canvas.width = size
    canvas.height = size

    const context = canvas.getContext("2d")
    const gradient = context.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2)
    gradient.addColorStop(0, "rgba(255,255,255,1)")
    gradient.addColorStop(0.4, "rgba(255,255,255,0.95)")
    gradient.addColorStop(0.62, "rgba(255,255,255,0.35)")
    gradient.addColorStop(1, "rgba(255,255,255,0)")
    context.fillStyle = gradient
    context.fillRect(0, 0, size, size)

    const texture = new THREE.CanvasTexture(canvas)
    texture.colorSpace = THREE.SRGBColorSpace
    return texture
  }

  createZoneMarker(name) {
    const texture = this.markerTexture || (this.markerTexture = this.createMarkerTexture())
    const group = new THREE.Group()

    const halo = new THREE.Sprite(new THREE.SpriteMaterial({
      map: texture,
      transparent: true,
      opacity: 0.55,
      depthTest: false,
      depthWrite: false
    }))
    halo.scale.set(0.2, 0.2, 1)
    halo.renderOrder = 30

    const core = new THREE.Sprite(new THREE.SpriteMaterial({
      map: texture,
      transparent: true,
      opacity: 1,
      depthTest: false,
      depthWrite: false
    }))
    core.scale.set(0.075, 0.075, 1)
    core.renderOrder = 31

    group.add(halo, core)
    group.userData.zone = name
    group.userData.halo = halo
    group.userData.core = core
    this.ensureZoneMarkers().add(group)
    this.zoneMarkerMeshes[name] = group
    return group
  }

  updateZoneMarkers() {
    if (!this.scene) return

    const statusByZone = {}
    ;(this.snapshot?.zones || []).forEach((zone) => {
      statusByZone[zone.name] = zone.status || "unknown"
    })

    Object.keys(ZONE_LABELS).forEach((name) => {
      const isVirtual = name === "psychological" || name === "immune"
      const existing = this.zoneMarkerMeshes[name]

      if (isVirtual && !statusByZone[name]) {
        if (existing) existing.visible = false
        return
      }

      const anchor = this.labelAnchor(name)
      if (!anchor) {
        if (existing) existing.visible = false
        return
      }

      const marker = existing || this.createZoneMarker(name)
      marker.position.copy(anchor)
      marker.visible = true
      marker.scale.setScalar(1)

      const status = statusByZone[name] || "unknown"
      const color = STATUS_MARKER_COLORS[status] || STATUS_MARKER_COLORS.unknown
      marker.userData.status = status
      marker.userData.halo.material.color.setHex(color)
      marker.userData.halo.material.opacity = status === "red" ? 0.7 : status === "yellow" ? 0.55 : status === "green" ? 0.4 : 0.22
      marker.userData.core.material.color.setHex(color)
    })
  }

  buildPlaceholderBody() {
    this.disposeBody()

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

    // HEAD: sphere + neck.
    const head = zone("head")
    this.addPart(head, new THREE.SphereGeometry(0.27, 32, 24), "head", [0, 1.72, 0])
    this.addPart(head, new THREE.CylinderGeometry(0.11, 0.13, 0.18, 20), "head", [0, 1.45, 0])
    // Decorative visor (not separately clickable, belongs to the head).
    const visor = new THREE.Mesh(
      new THREE.SphereGeometry(0.276, 32, 16, 0, Math.PI * 2, 0, Math.PI * 0.42),
      new THREE.MeshStandardMaterial({ color: 0x0ea5e9, transparent: true, opacity: 0.32, roughness: 0.1, metalness: 0.6 })
    )
    visor.position.set(0, 1.73, 0.02)
    visor.rotation.x = Math.PI / 2.15
    head.add(visor)

    // CHEST: wide capsule + shoulders.
    const chest = zone("chest")
    this.addPart(chest, new THREE.CapsuleGeometry(0.34, 0.34, 10, 24), "chest", [0, 1.08, 0])
    this.addPart(chest, new THREE.SphereGeometry(0.17, 20, 16), "chest", [-0.4, 1.22, 0])
    this.addPart(chest, new THREE.SphereGeometry(0.17, 20, 16), "chest", [0.4, 1.22, 0])

    // ABDOMEN: narrower capsule.
    const abdomen = zone("abdomen")
    this.addPart(abdomen, new THREE.CapsuleGeometry(0.28, 0.25, 10, 24), "abdomen", [0, 0.62, 0])

    // LIMBS: arms and legs.
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

    this.refreshZoneCenters()
  }

  // Computes one world-space anchor per zone for labels and selection markers.
  refreshZoneCenters() {
    this.zoneCenters = {}
    Object.entries(this.zoneGroups).forEach(([name, object]) => {
      const box = new THREE.Box3().setFromObject(object)
      if (box.isEmpty()) return

      this.zoneCenters[name] = box.getCenter(new THREE.Vector3())
    })

    this.updateZoneMarkers()
  }

  // ---------------------------------------------------------------------------
  // Zone labels with leader lines (readable without clicking, colorblind safe)
  // ---------------------------------------------------------------------------
  setupZoneLabels() {
    if (!this.hasCanvasTarget) return

    this.labelLayer = document.createElement("div")
    this.labelLayer.className = "pointer-events-none absolute inset-0 z-[5] overflow-hidden"
    this.canvasTarget.appendChild(this.labelLayer)
    this.labelElements = {}

    Object.keys(ZONE_LABELS).forEach((name) => {
      const label = document.createElement("div")
      label.className = "absolute hidden -translate-y-1/2 items-center gap-1.5 whitespace-nowrap rounded-full border border-slate-700 bg-slate-950/85 px-2 py-0.5 text-[10px] font-medium text-slate-200 shadow-lg backdrop-blur"
      label.dataset.body3dLabel = name

      const line = document.createElement("span")
      line.className = "absolute right-full top-1/2 h-px w-6 bg-slate-500/80"

      const dot = document.createElement("span")
      dot.dataset.labelDot = ""
      dot.className = "h-2 w-2 rounded-full bg-slate-500"

      const text = document.createElement("span")
      text.dataset.labelText = ""
      text.textContent = ZONE_LABELS[name]

      label.append(line, dot, text)
      this.labelLayer.appendChild(label)
      this.labelElements[name] = label
    })
  }

  updateZoneLabels() {
    if (!this.camera || !this.labelLayer || !this.hasCanvasTarget) return

    const width = this.canvasTarget.clientWidth
    const height = this.canvasTarget.clientHeight
    if (!width || !height) return

    const statusByZone = {}
    const countByZone = {}
    ;(this.snapshot?.zones || []).forEach((zone) => {
      statusByZone[zone.name] = zone.status || "unknown"
      countByZone[zone.name] = this.alertCount(zone)
    })

    Object.entries(this.labelElements).forEach(([name, label]) => {
      const isVirtual = name === "psychological" || name === "immune"
      if (isVirtual && !statusByZone[name]) {
        label.classList.add("hidden")
        return
      }

      const anchor = this.labelAnchor(name)
      if (!anchor) {
        label.classList.add("hidden")
        return
      }

      const projected = anchor.clone().project(this.camera)
      const x = (projected.x * 0.5 + 0.5) * width
      const y = (-projected.y * 0.5 + 0.5) * height

      if (projected.z > 1 || x < -40 || x > width + 40 || y < -20 || y > height + 20) {
        label.classList.add("hidden")
        return
      }

      const status = statusByZone[name] || "unknown"
      const alerts = countByZone[name] || 0

      label.style.left = `${x + 10}px`
      label.style.top = `${y}px`
      label.classList.remove("hidden")

      const dot = label.querySelector("[data-label-dot]")
      if (dot) dot.className = `h-2 w-2 rounded-full ${LABEL_DOT_CLASSES[status] || LABEL_DOT_CLASSES.unknown}`

      const text = label.querySelector("[data-label-text]")
      if (text) {
        text.textContent = alerts > 0
          ? `${ZONE_LABELS[name]} · ${alerts} alert${alerts === 1 ? "" : "s"}`
          : `${ZONE_LABELS[name]} · ${STATUS_LABELS[status] || status}`
      }
    })
  }

  labelAnchor(name) {
    let baseName = name
    let offset = LABEL_ANCHOR_OFFSETS[name]

    if (name === "psychological") {
      baseName = "head"
      offset = [0.35, 0.34, 0]
    } else if (name === "immune") {
      baseName = "chest"
      offset = [-0.58, -0.18, 0]
    }

    const center = this.zoneCenters[baseName]
    if (!center) return null

    return center.clone().add(new THREE.Vector3(...(offset || [0, 0, 0])))
  }

  alertCount(zone) {
    const indicators = zone.indicators || []
    const alerts = indicators.filter((indicator) => indicator.status === "red" || indicator.status === "yellow").length
    if (alerts > 0) return alerts
    return zone.status === "red" || zone.status === "yellow" ? 1 : 0
  }

  // ---------------------------------------------------------------------------
  // Interaction: raycaster
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
      if (moved > 6) return // camera drag, not a click

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

    // Subtle pulse only when the selected zone requires medical evaluation.
    if (this.marker?.visible) {
      this.marker.quaternion.copy(this.camera.quaternion)
      const critical = this.selectedZone?.status === "red"
      const pulse = critical ? 1 + Math.sin(performance.now() * 0.004) * 0.08 : 1
      this.marker.scale.setScalar(pulse)
    }

    const now = performance.now()
    Object.values(this.zoneMarkerMeshes || {}).forEach((marker) => {
      if (!marker.visible) return
      const critical = marker.userData.status === "red"
      marker.scale.setScalar(critical ? 1 + Math.sin(now * 0.005) * 0.2 : 1)
    })

    this.updateZoneLabels()
    this.renderer.render(this.scene, this.camera)
  }

  resetView() {
    this.camera.position.set(0, 0.6, 3.4)
    this.controls.target.set(0, 0.6, 0)
    this.controls.update()
  }

  // ---------------------------------------------------------------------------
  // Data and status painting
  // ---------------------------------------------------------------------------
  async loadStatus() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      this.snapshot = await response.json()
      this.applyStatuses()
      this.updateOverall()
      this.updatePoints()
      this.updateFallback()

      const zones = this.snapshot.zones || []
      const worst = zones.find((zone) => zone.status === "red") ||
                    zones.find((zone) => zone.status === "yellow") ||
                    zones.find((zone) => zone.name === "chest")
      if (worst && !this.selectedZone) this.selectZone(worst.name)
      if (this.selectedZone) this.renderZonePanel(this.selectedZone)
    } catch (error) {
      console.error("Could not load /api/health_status", error)
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

    this.updateZoneMarkers()
  }

  selectZone(zoneName, point = null) {
    this.selectedZone = (this.snapshot?.zones || []).find((zone) => zone.name === zoneName)
    this.renderZonePanel(this.selectedZone)
    this.showSelectionMarker(zoneName, point)
  }

  selectZoneFromMap(event) {
    event.preventDefault()
    const zoneName = event.params?.zone
    if (zoneName) this.selectZone(zoneName)
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

    const rank = { red: 0, yellow: 1, green: 2, unknown: 3 }
    const sorted = [...indicators].sort((a, b) => (rank[a.status] ?? 9) - (rank[b.status] ?? 9))
    const alertIndicators = sorted.filter((indicator) => indicator.status !== "green" && indicator.status !== "unknown")
    const normalIndicators = sorted.filter((indicator) => indicator.status === "green" || indicator.status === "unknown")

    const causeLabels = alertIndicators
      .filter((indicator) => indicator.status === status)
      .map((indicator) => indicator.label)
      .filter(Boolean)
    const cause = causeLabels.length ? causeLabels.slice(0, 3).join(" and ") : (zone.description || "")
    const causePrefix = status === "red" ? "Medical evaluation due to:" : status === "yellow" ? "Follow-up due to:" : ""

    const badgeFor = (value) => {
      return {
        green: "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
        yellow: "bg-amber-500/15 text-amber-300 border-amber-500/40",
        red: "bg-rose-500/15 text-rose-300 border-rose-500/40"
      }[value] || "bg-slate-500/15 text-slate-300 border-slate-500/40"
    }

    const alertRows = (this.snapshot?.zones || [])
      .filter((other) => other.name !== zone.name && other.status !== "green" && other.status !== "unknown")
      .sort((a, b) => (rank[a.status] ?? 9) - (rank[b.status] ?? 9))
      .map((other) => {
        const worst = (other.indicators || []).find((item) => item.status === other.status) || (other.indicators || [])[0]
        const detail = worst ? `${worst.label} · ${worst.value} ${worst.unit}` : "Review zone indicators"
        return `
          <li class="flex items-start justify-between gap-2 rounded-lg border border-slate-700 bg-slate-950/50 px-2.5 py-2">
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
        <p class="text-[10px] font-semibold uppercase tracking-wider text-amber-200">Also under alert</p>
        <ul class="mt-2 space-y-1.5">${alertRows}</ul>
      </div>
    ` : ""

    const indicatorRow = (indicator) => {
      const badge = badgeFor(indicator.status)
      const recommendation = indicator.recommendation?.text || ""
      const urgency = indicator.recommendation?.urgency || "routine"
      const urgencyLabel = { urgent: "Priority Attention", watch: "Under Watch", routine: "Routine" }[urgency] || "Routine"
      const urgencyClass = urgency === "urgent" ? "text-rose-300" : urgency === "watch" ? "text-amber-300" : "text-slate-400"
      const baselineNote = indicator.baseline_note
        ? `<p class="mt-0.5 text-[10px] text-cyan-300">${this.escape(indicator.baseline_note)}</p>`
        : ""
      const hazardLabels = (indicator.hazards || []).map((hazard) => HAZARD_LABELS[hazard] || hazard)
      const hazardNote = hazardLabels.length
        ? `<p class="mt-1 text-[10px] text-slate-500">HRP hazard: ${this.escape(hazardLabels.join(", "))}</p>`
        : ""
      const informationalNote = indicator.informational
        ? `<p class="mt-0.5 text-[10px] text-slate-500">Informational: sleep does not drive severity.</p>`
        : ""

      return `
        <div class="rounded-xl border border-slate-700 bg-slate-950/60 p-3">
          <div class="flex items-start justify-between gap-2">
            <div>
              <p class="text-sm font-medium text-slate-200">${this.escape(indicator.label)}</p>
              <p class="mt-1 text-lg font-semibold text-white">${indicator.value} <span class="text-xs font-normal text-slate-400">${this.escape(indicator.unit)}</span></p>
              ${baselineNote}${informationalNote}
            </div>
            <span class="inline-flex shrink-0 items-center rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase ${badge}">${this.escape(STATUS_LABELS[indicator.status] || indicator.status)}</span>
          </div>
          ${recommendation ? `<p class="mt-2 text-xs leading-relaxed text-slate-300">${this.escape(recommendation)}</p>` : ""}
          ${hazardNote}
          <p class="mt-1 text-[10px] uppercase tracking-wider ${urgencyClass}">${urgencyLabel}</p>
        </div>
      `
    }

    const normalRow = (indicator) => `
      <div class="flex items-center justify-between gap-2 rounded-lg border border-slate-700 bg-slate-950/40 px-2.5 py-1.5">
        <span class="min-w-0 truncate text-[11px] text-slate-300">${this.escape(indicator.label)}</span>
        <span class="shrink-0 text-[11px] font-medium text-slate-200">${indicator.value} <span class="text-[10px] font-normal text-slate-500">${this.escape(indicator.unit)}</span>${indicator.informational ? ' <span class="text-[10px] font-normal text-slate-500">· informational</span>' : ""}</span>
      </div>
    `

    const normalsBlock = normalIndicators.length ? `
      <details class="mt-3 rounded-xl border border-slate-700 bg-slate-950/40 p-3">
        <summary class="cursor-pointer text-[11px] font-medium text-cyan-300">
          View ${normalIndicators.length} normal indicator${normalIndicators.length === 1 ? "" : "s"}
        </summary>
        <div class="mt-2 space-y-1.5">${normalIndicators.map(normalRow).join("")}</div>
      </details>
    ` : ""

    const causeBlock = causePrefix
      ? `<p class="mt-3 text-sm leading-relaxed text-slate-200"><span class="font-semibold ${status === "red" ? "text-rose-300" : "text-amber-300"}">${causePrefix}</span> ${this.escape(cause)}</p>`
      : `<p class="mt-3 text-sm leading-relaxed text-slate-300">${this.escape(cause || "All monitored indicators are within normal range.")}</p>`

    this.panelTarget.innerHTML = `
      <div class="flex items-start justify-between gap-3">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Selected Zone</p>
          <h2 class="mt-1 text-xl font-semibold text-white">${this.escape(ZONE_LABELS[zone.name] || zone.name)}</h2>
        </div>
        <span class="inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold uppercase ${statusClass}">${this.escape(STATUS_LABELS[status] || status)}</span>
      </div>
      ${causeBlock}
      ${zone.note ? `<p class="mt-2 rounded-lg border border-cyan-500/20 bg-cyan-500/5 px-2.5 py-2 text-[11px] leading-relaxed text-cyan-100/90">${this.escape(zone.note)}</p>` : ""}
      ${zone.hazard_reason ? `<div class="mt-2 rounded-lg border border-slate-700 bg-slate-950/40 px-2.5 py-2"><p class="text-[10px] font-semibold uppercase tracking-wider text-slate-500">Why these hazards</p><p class="mt-1 text-[11px] leading-relaxed text-slate-300">${this.escape(zone.hazard_reason)}</p></div>` : ""}
      <div class="mt-4 space-y-2">
        ${alertIndicators.map(indicatorRow).join("") || '<p class="rounded-xl border border-dashed border-slate-700 p-3 text-sm text-slate-400">No measurements for this zone.</p>'}
      </div>
      ${normalsBlock}
      ${alertsBlock}
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
      Overall status: <span class="font-semibold uppercase">${this.escape(STATUS_LABELS[status] || status)}</span>
      ${alertZones.length && status !== "green" ? `<span class="text-xs font-normal opacity-80">· ${status === "red" ? "zones requiring medical evaluation" : "zones needing follow-up"}: ${this.escape(alertNames)}</span>` : ""}
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

  // ---------------------------------------------------------------------------
  // 2D plan B (accessible list, also useful if the 3D scene is slow)
  // ---------------------------------------------------------------------------
  toggleFallback(event) {
    if (event) event.preventDefault()

    this.fallbackVisible = !this.fallbackVisible
    if (this.hasFallbackTarget) this.fallbackTarget.classList.toggle("hidden", !this.fallbackVisible)
    if (this.hasCanvasTarget) this.canvasTarget.classList.toggle("hidden", this.fallbackVisible)

    if (!this.fallbackVisible) setTimeout(() => this.resize(), 0)
  }

  showFallback(message = null) {
    if (message && this.hasFallbackTarget) {
      this.fallbackTarget.dataset.message = message
    }
    if (!this.fallbackVisible) this.toggleFallback()
    this.updateFallback()
  }

  updateFallback() {
    if (!this.hasFallbackTarget) return

    const zones = this.snapshot?.zones || []
    const message = this.fallbackTarget.dataset.message
    const intro = message ? `<p class="mb-3 rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-[11px] text-amber-200">${this.escape(message)}</p>` : ""

    const rows = zones.map((zone) => {
      const status = zone.status || "unknown"
      const alerts = this.alertCount(zone)
      const badge = {
        green: "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
        yellow: "bg-amber-500/15 text-amber-300 border-amber-500/40",
        red: "bg-rose-500/15 text-rose-300 border-rose-500/40"
      }[status] || "bg-slate-500/15 text-slate-300 border-slate-500/40"
      const dot = LABEL_DOT_CLASSES[status] || LABEL_DOT_CLASSES.unknown

      const zoneStatusText = `${ZONE_LABELS[zone.name] || zone.name}: ${STATUS_LABELS[status] || status}, ${alerts} alert${alerts === 1 ? "" : "s"}. Show indicators.`

      return `
        <button type="button" data-action="click->body-3d#selectZoneFromMap" data-body-3d-zone-param="${this.escape(zone.name)}"
                aria-label="${this.escape(zoneStatusText)}"
                class="flex w-full items-center justify-between gap-3 rounded-xl border border-slate-700 bg-slate-950/60 px-3 py-2.5 text-left transition hover:border-cyan-500/50">
          <span class="flex min-w-0 items-center gap-2">
            <span class="h-2 w-2 shrink-0 rounded-full ${dot}" aria-hidden="true"></span>
            <span class="min-w-0">
              <span class="block text-sm font-medium text-slate-200">${this.escape(ZONE_LABELS[zone.name] || zone.name)}</span>
              <span class="block text-[10px] text-slate-500">${alerts > 0 ? `${alerts} alert${alerts === 1 ? "" : "s"}` : "No alerts"}</span>
            </span>
          </span>
          <span class="shrink-0 rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase ${badge}" role="status">${this.escape(STATUS_LABELS[status] || status)}</span>
        </button>
      `
    }).join("")

    this.fallbackTarget.innerHTML = `
      ${intro}
      <p class="mb-2 text-[10px] font-semibold uppercase tracking-wider text-slate-500">2D map (accessible alternative)</p>
      <div class="space-y-2">${rows || '<p class="text-sm text-slate-400">No zone data yet.</p>'}</div>
    `
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
