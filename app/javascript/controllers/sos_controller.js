import { Controller } from "@hotwired/stimulus"

// Modal SOS: "Solicitar Telemetría Médica Prioritaria".
//
// El botón solo existe en el panel lateral cuando la zona seleccionada está
// en estado crítico (lo inyecta body_3d_controller). La barra de progreso es
// simulada y dura 3 segundos, como si se empaquetara y enviara la telemetría
// a Houston por el enlace de alta prioridad.
const DURATION = 3000

const START_MESSAGE =
  "Transmitting telemetry to Houston... 20 min delay."
const END_MESSAGE =
  "✅ Message queued. Estimated delay: 20 minutes. Stay calm and follow the protocol."

const MESSAGE_START_CLASSES = ["border-rose-500/25", "bg-rose-500/5", "text-rose-100"]
const MESSAGE_END_CLASSES = ["border-emerald-500/30", "bg-emerald-500/10", "text-emerald-200"]

export default class extends Controller {
  static targets = ["modal", "bar", "message", "stage", "percent"]

  connect() {
    this.onKeydown = (event) => {
      if (event.key === "Escape" && this.isOpen) this.close()
    }
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    this.stop()
  }

  get isOpen() {
    return !this.modalTarget.classList.contains("hidden")
  }

  open() {
    this.stop()
    this.reset()
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    this.start()
  }

  close() {
    this.stop()
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
  }

  reset() {
    this.barTarget.style.width = "0%"
    this.percentTarget.textContent = "0%"
    this.stageTarget.textContent = "Packaging telemetry…"
    this.messageTarget.textContent = START_MESSAGE
    this.messageTarget.classList.remove(...MESSAGE_END_CLASSES)
    this.messageTarget.classList.add(...MESSAGE_START_CLASSES)
  }

  start() {
    this.startedAt = performance.now()

    const tick = (now) => {
      const elapsed = now - this.startedAt
      const ratio = Math.min(1, elapsed / DURATION)
      const percent = Math.round(ratio * 100)

      this.barTarget.style.width = `${percent}%`
      this.percentTarget.textContent = `${percent}%`

      if (elapsed < 1200) {
        this.stageTarget.textContent = "Packaging telemetry…"
      } else if (elapsed < 2400) {
        this.stageTarget.textContent = "Establishing high-priority link…"
      } else if (elapsed < DURATION) {
        this.stageTarget.textContent = "Transmitting to Houston…"
      }

      if (ratio < 1) {
        this.raf = requestAnimationFrame(tick)
      } else {
        this.finish()
      }
    }

    this.raf = requestAnimationFrame(tick)
  }

  finish() {
    this.stageTarget.textContent = "Transmission complete · Tempus Pro"
    this.messageTarget.textContent = END_MESSAGE
    this.messageTarget.classList.remove(...MESSAGE_START_CLASSES)
    this.messageTarget.classList.add(...MESSAGE_END_CLASSES)
  }

  stop() {
    if (this.raf) cancelAnimationFrame(this.raf)
    this.raf = null
  }
}
