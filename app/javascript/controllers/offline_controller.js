import { Controller } from "@hotwired/stimulus"

// Modo offline / simulación de pérdida de enlace con Tierra.
//
// - Escucha los eventos nativos `offline` y `online` del navegador.
// - Cambia el badge de enlace (verde ACTIVO <-> ámbar OFFLINE).
// - Guarda las mediciones en localStorage cuando no hay red.
// - Al recuperar el enlace, reenvía la cola a Rails y dispara
//   "health:reading-created" para que el cuerpo 3D y las gráficas se actualicen.
const STORAGE_KEY = "astronaut_health:pending_readings"

const BADGE_STATES = {
  online: ["border-emerald-500/40", "bg-emerald-500/10", "text-emerald-300"],
  offline: ["border-amber-500/40", "bg-amber-500/10", "text-amber-300"]
}

const TOAST_TONES = {
  amber: ["border-amber-500/40", "bg-amber-500/15", "text-amber-100"],
  emerald: ["border-emerald-500/40", "bg-emerald-500/15", "text-emerald-100"]
}

const ALL_BADGE_CLASSES = Object.values(BADGE_STATES).flat()
const ALL_TOAST_CLASSES = Object.values(TOAST_TONES).flat()

export default class extends Controller {
  static targets = ["badge", "dot", "label", "pending", "toast", "toastTitle", "toastBody"]
  static values = { url: { type: String, default: "/health_readings" } }

  connect() {
    this.syncing = false

    this.onOffline = () => {
      this.updateBadge(true)
      this.showToast("📡 Link with Earth lost", "Autonomous mode enabled. Data will be stored on this device.", "amber")
    }

    this.onOnline = () => {
      this.updateBadge(false)
      this.flush()
    }

    window.addEventListener("offline", this.onOffline)
    window.addEventListener("online", this.onOnline)

    this.updateBadge(!navigator.onLine)
    this.updatePendingCount()

    // Si quedaron mediciones de una sesión anterior, intenta sincronizarlas.
    if (navigator.onLine) this.flush()
  }

  disconnect() {
    window.removeEventListener("offline", this.onOffline)
    window.removeEventListener("online", this.onOnline)
    clearTimeout(this.toastTimer)
  }

  // Cola local. La usa health_form_controller cuando no hay conexión.
  enqueue(formElement) {
    const data = new FormData(formElement)
    const reading = {
      indicator_type: data.get("health_reading[indicator_type]"),
      value: data.get("health_reading[value]"),
      unit: data.get("health_reading[unit]") || "",
      measured_at: data.get("health_reading[measured_at]") || new Date().toISOString(),
      is_baseline: data.get("health_reading[is_baseline]") === "1",
      confirmed: data.get("health_reading[confirmed]") === "1",
      // Guardamos la URL con misión/astronauta para no mezclar colas si el
      // usuario cambia de selección antes de recuperar el enlace.
      sync_url: this.urlValue,
      queued_at: new Date().toISOString()
    }

    const queue = this.readQueue()
    queue.push(reading)
    this.writeQueue(queue)
    this.updatePendingCount()

    this.showToast(
      "Offline. Data saved locally.",
      "They will sync when the link is restored.",
      "amber"
    )

    return reading
  }

  // Envía la cola a Rails uno por uno. Si un POST falla, la medición se
  // conserva en localStorage para el siguiente intento.
  async flush() {
    if (this.syncing || !navigator.onLine) return

    const queue = this.readQueue()
    if (queue.length === 0) return

    this.syncing = true
    let synced = 0
    const remaining = []

    for (const reading of queue) {
      try {
        const response = await this.postReading(reading)
        if (!response.ok) throw new Error(`HTTP ${response.status}`)

        const data = await response.json().catch(() => ({}))
        document.dispatchEvent(new CustomEvent("health:reading-created", { detail: data }))
        synced += 1
      } catch (error) {
        console.error("Could not sync an offline measurement", error)
        remaining.push(reading)
      }
    }

    this.writeQueue(remaining)
    this.updatePendingCount()
    this.syncing = false

    if (synced > 0) {
      this.showToast(
        "✅ Link restored",
        `${synced} measurement(s) synced with Houston.`,
        "emerald"
      )
    }
  }

  async postReading(reading) {
    const body = new FormData()
    body.append("health_reading[indicator_type]", reading.indicator_type)
    body.append("health_reading[value]", reading.value)
    body.append("health_reading[unit]", reading.unit)
    body.append("health_reading[measured_at]", reading.measured_at)
    body.append("health_reading[is_baseline]", reading.is_baseline ? "1" : "0")
    body.append("health_reading[confirmed]", reading.confirmed ? "1" : "0")

    return fetch(reading.sync_url || this.urlValue, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: body
    })
  }

  // ---------------------------------------------------------------------------
  // Estado visual
  // ---------------------------------------------------------------------------
  updateBadge(offline) {
    if (this.hasBadgeTarget) {
      this.badgeTarget.classList.remove(...ALL_BADGE_CLASSES)
      this.badgeTarget.classList.add(...(offline ? BADGE_STATES.offline : BADGE_STATES.online))
    }

    if (this.hasDotTarget) {
      this.dotTarget.classList.toggle("bg-amber-400", offline)
      this.dotTarget.classList.toggle("bg-emerald-400", !offline)
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = offline ? "⚠️ Autonomous mode (Offline)" : "📡 Link with Earth: ACTIVE"
    }
  }

  updatePendingCount() {
    if (!this.hasPendingTarget) return

    const count = this.readQueue().length
    this.pendingTarget.textContent = `${count} queued`
    this.pendingTarget.classList.toggle("hidden", count === 0)
    this.pendingTarget.classList.toggle("inline-flex", count > 0)
  }

  showToast(title, body, tone) {
    if (!this.hasToastTarget) return

    this.toastTitleTarget.textContent = title
    this.toastBodyTarget.textContent = body

    this.toastTarget.classList.remove("hidden", ...ALL_TOAST_CLASSES)
    this.toastTarget.classList.add(...(TOAST_TONES[tone] || TOAST_TONES.amber))

    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => this.toastTarget.classList.add("hidden"), 6000)
  }

  // ---------------------------------------------------------------------------
  // localStorage seguro (puede fallar en modo privado o sin permisos)
  // ---------------------------------------------------------------------------
  readQueue() {
    try {
      const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]")
      return Array.isArray(parsed) ? parsed : []
    } catch (error) {
      console.error("Could not read offline queue", error)
      return []
    }
  }

  writeQueue(queue) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(queue))
    } catch (error) {
      console.error("Could not save offline queue", error)
    }
  }
}
