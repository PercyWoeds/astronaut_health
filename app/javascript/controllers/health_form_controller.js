import { Controller } from "@hotwired/stimulus"

// Gestiona el modal y el envío del formulario de mediciones vía fetch.
// Al guardar, emite "health:reading-created" para que el cuerpo 3D y las
// gráficas se actualicen sin recargar la página.
export default class extends Controller {
  static targets = ["modal", "form", "indicator", "unit", "value", "error", "submitButton", "toast", "toastTitle", "toastBody"]
  static values = { url: { type: String, default: "/health_readings" } }

  connect() {
    this.onKeydown = (event) => {
      if (event.key === "Escape" && this.isOpen) this.close()
    }
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    clearTimeout(this.toastTimer)
  }

  get isOpen() {
    return !this.modalTarget.classList.contains("hidden")
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    this.clearError()
    setTimeout(() => this.valueTarget?.focus(), 50)
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    this.clearError()
  }

  updateUnit() {
    const option = this.indicatorTarget.selectedOptions[0]
    if (option?.dataset.unit) this.unitTarget.value = option.dataset.unit
  }

  async submit(event) {
    event.preventDefault()
    this.clearError()

    // Modo autónomo: sin enlace con Tierra, la medición se guarda en
    // localStorage y se sincroniza al recuperar conexión (offline_controller).
    if (!navigator.onLine) {
      this.saveOffline()
      return
    }

    this.setBusy(true)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: new FormData(this.formTarget)
      })

      const data = await response.json().catch(() => ({}))

      if (!response.ok) {
        const message = Array.isArray(data.errors) ? data.errors.join(". ") : "No se pudo guardar la medición."
        throw new Error(message)
      }

      document.dispatchEvent(new CustomEvent("health:reading-created", { detail: data }))
      this.showToast(data)
      this.formTarget.reset()
      this.updateUnit()
      this.close()
    } catch (error) {
      // Si el enlace se cae a mitad del POST, no perdemos la medición.
      if (!navigator.onLine || error instanceof TypeError) {
        this.saveOffline()
        return
      }

      this.showError(error.message)
    } finally {
      this.setBusy(false)
    }
  }

  // Guarda el formulario en la cola offline gestionada por offline_controller.
  saveOffline() {
    const offline = this.application.getControllerForElementAndIdentifier(this.element, "offline")

    if (!offline?.enqueue) {
      this.showError("Sin conexión y no se pudo acceder al almacenamiento local.")
      return
    }

    offline.enqueue(this.formTarget)
    this.formTarget.reset()
    this.updateUnit()
    this.close()
  }

  setBusy(busy) {
    if (!this.hasSubmitButtonTarget) return
    this.submitButtonTarget.disabled = busy
    this.submitButtonTarget.textContent = busy ? "Guardando…" : "Guardar medición"
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  showToast(data) {
    if (!this.hasToastTarget) return

    const reading = data.reading || {}
    const awards = data.awarded_achievements || []
    const statusLabel = { green: "Normal", yellow: "Vigilar", red: "Crítico" }[reading.status] || reading.status

    this.toastTitleTarget.textContent = `Medición guardada: ${reading.label || "indicador"} = ${reading.value} ${reading.unit || ""}`
    this.toastBodyTarget.textContent = awards.length
      ? `¡Nuevo logro! ${awards.map((award) => `${award.name} (+${award.points} pts)`).join(", ")} · Total: ${data.total_points} pts`
      : `Estado: ${statusLabel}. ${reading.recommendation?.text || ""}`

    this.toastTarget.classList.remove("hidden", "border-emerald-500/40", "bg-emerald-500/15", "text-emerald-100")
    const danger = reading.status === "red"
    this.toastTarget.classList.add(...(danger
      ? ["border-rose-500/40", "bg-rose-500/15", "text-rose-100"]
      : ["border-emerald-500/40", "bg-emerald-500/15", "text-emerald-100"]))

    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => this.toastTarget.classList.add("hidden"), 6000)
  }
}
