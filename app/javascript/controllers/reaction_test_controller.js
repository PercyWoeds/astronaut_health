import { Controller } from "@hotwired/stimulus"

// Test de reacción de 1 minuto (CIPHER / Spatial Cognition).
// Estado: idle -> waiting (2-5 s) -> ready -> guarda la lectura.
const BUTTON_VARIANTS = {
  idle: ["border-slate-600", "bg-slate-800", "text-slate-100", "hover:bg-slate-700"],
  waiting: ["border-rose-500", "bg-rose-600", "text-white", "hover:bg-rose-600"],
  ready: ["border-emerald-400", "bg-emerald-500", "text-slate-950", "animate-pulse", "hover:bg-emerald-500"]
}

const ALL_BUTTON_CLASSES = Object.values(BUTTON_VARIANTS).flat()

export default class extends Controller {
  static targets = ["button", "prompt", "result", "warning", "error"]
  static values = { url: { type: String, default: "/health_readings" } }

  connect() {
    this.state = "idle"
    this.readyAt = null
    this.setButton("Start test", "idle")
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  press() {
    if (this.state === "waiting") {
      this.falseStart()
      return
    }

    if (this.state === "ready") {
      this.finish()
      return
    }

    this.start()
  }

  start() {
    clearTimeout(this.timer)
    this.state = "waiting"
    this.readyAt = null
    this.hideMessages()
    this.resultTarget.textContent = ""
    this.promptTarget.textContent = "Wait for green…"
    this.setButton("Wait for green…", "waiting")

    const delay = 2_000 + Math.random() * 3_000
    this.timer = setTimeout(() => this.showReady(), delay)
  }

  showReady() {
    this.state = "ready"
    this.readyAt = performance.now()
    this.promptTarget.textContent = "Now!"
    this.setButton("CLICK NOW!", "ready")
  }

  finish() {
    const reactionMs = Math.round(performance.now() - this.readyAt)
    clearTimeout(this.timer)
    this.state = "idle"
    this.readyAt = null

    this.promptTarget.textContent = "Test completed. You can repeat it."
    this.resultTarget.textContent = `Reaction time: ${reactionMs} ms`
    this.setButton("Repeat test", "idle")

    if (reactionMs > 500) {
      this.warningTarget.classList.remove("hidden")
    } else {
      this.warningTarget.classList.add("hidden")
    }

    this.save(reactionMs)
  }

  falseStart() {
    clearTimeout(this.timer)
    this.state = "idle"
    this.readyAt = null
    this.resultTarget.textContent = ""
    this.promptTarget.textContent = "You jumped the gun. Try again."
    this.showError("You clicked before the green appeared.")
    this.setButton("Repeat test", "idle")
  }

  async save(reactionMs) {
    const formData = new FormData()
    formData.append("health_reading[indicator_type]", "reaction_time")
    formData.append("health_reading[value]", String(reactionMs))
    formData.append("health_reading[reaction_time_ms]", String(reactionMs))

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: formData
      })

      const data = await response.json().catch(() => ({}))
      if (!response.ok) {
        throw new Error(Array.isArray(data.errors) ? data.errors.join(". ") : "Could not save the test.")
      }

      document.dispatchEvent(new CustomEvent("health:reading-created", { detail: data }))
    } catch (error) {
      this.showError(error.message)
    }
  }

  setButton(label, variant) {
    this.buttonTarget.textContent = label
    this.buttonTarget.classList.remove(...ALL_BUTTON_CLASSES)
    this.buttonTarget.classList.add(...BUTTON_VARIANTS[variant])
  }

  hideMessages() {
    this.warningTarget.classList.add("hidden")
    this.errorTarget.classList.add("hidden")
    this.errorTarget.textContent = ""
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }
}