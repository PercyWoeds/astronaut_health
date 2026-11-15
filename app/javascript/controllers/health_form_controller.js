import { Controller } from "@hotwired/stimulus"

// Gestiona el modal y el envío del formulario de mediciones vía fetch.
// Al guardar, emite "health:reading-created" para que el cuerpo 3D y las
// gráficas se actualicen sin recargar la página.
const UNIT_CONVERSIONS = {
  blood_pressure_systolic: { mmHg: 1, kPa: 7.50062 },
  blood_pressure_diastolic: { mmHg: 1, kPa: 7.50062 },
  heart_rate: { bpm: 1 },
  blood_glucose: { "mg/dL": 1, "mmol/L": 18.0182 },
  body_temperature: { "°C": 1, "°F": 1 },
  sleep_hours: { h: 1 },
  mood_score: { "1-10": 1 },
  reaction_time: { ms: 1 },
  meals_completed_percent: { "%": 1 },
  social_contact_minutes: { min: 1 }
}

const TOAST_TONES = {
  emerald: ["border-emerald-500/40", "bg-emerald-500/15", "text-emerald-100"],
  rose: ["border-rose-500/40", "bg-rose-500/15", "text-rose-100"],
  amber: ["border-amber-500/40", "bg-amber-500/15", "text-amber-100"]
}

const ALL_TOAST_CLASSES = Object.values(TOAST_TONES).flat()

export default class extends Controller {
  static targets = [
    "modal", "form", "indicator", "unit", "value", "valueError", "help", "error",
    "confirmed", "baseline", "submitButton", "toast", "toastTitle", "toastBody"
  ]
  static values = { url: { type: String, default: "/health_readings" } }

  connect() {
    this.currentUnit = null

    this.onKeydown = (event) => {
      if (event.key === "Escape" && this.isOpen) this.close()
    }
    document.addEventListener("keydown", this.onKeydown)
    this.updateUnit()
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
    this.clearValueError()
    this.updateUnit()
    setTimeout(() => this.valueTarget?.focus(), 50)
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    this.clearError()
    this.clearValueError()
  }

  // Abre el modal con un indicador preseleccionado (usado por el aviso de pendientes).
  openFor(event) {
    this.open()

    const indicator = event.params?.indicator
    if (!indicator || !this.hasIndicatorTarget) return

    this.indicatorTarget.value = indicator
    this.updateUnit()
  }

  // Configura las unidades compatibles y actualiza el texto de ayuda.
  updateUnit() {
    if (!this.hasIndicatorTarget || !this.hasUnitTarget) return

    const option = this.indicatorTarget.selectedOptions[0]
    if (!option) return

    const canonical = option.dataset.unit
    const units = (option.dataset.units || canonical || "").split(",").filter(Boolean)

    Array.from(this.unitTarget.options).forEach((unitOption) => {
      const allowed = units.includes(unitOption.value)
      unitOption.disabled = !allowed
      unitOption.hidden = !allowed
    })

    this.unitTarget.value = canonical
    this.currentUnit = canonical
    this.updateHelp()
    this.clearValueError()
  }

  // Convierte el valor mostrado al cambiar de unidad (mg/dL <-> mmol/L, °C <-> °F, etc.).
  convertValue() {
    if (!this.hasIndicatorTarget || !this.hasValueTarget || !this.hasUnitTarget) return

    const indicator = this.indicatorTarget.value
    const oldUnit = this.currentUnit
    const newUnit = this.unitTarget.value
    const raw = parseFloat(this.valueTarget.value)

    if (Number.isFinite(raw) && oldUnit && newUnit && oldUnit !== newUnit) {
      const canonical = this.toCanonical(indicator, raw, oldUnit)
      this.valueTarget.value = this.formatNumber(this.fromCanonical(indicator, canonical, newUnit))
    }

    this.currentUnit = newUnit
    this.updateHelp()
    this.clearValueError()
  }

  canonicalize() {
    if (!this.hasIndicatorTarget || !this.hasValueTarget || !this.hasUnitTarget) return

    const indicator = this.indicatorTarget.value
    const unit = this.unitTarget.value
    const raw = parseFloat(this.valueTarget.value)
    const canonical = this.canonicalUnit()

    if (!Number.isFinite(raw) || !canonical || unit === canonical) return

    this.valueTarget.value = this.formatNumber(this.toCanonical(indicator, raw, unit))
    this.unitTarget.value = canonical
    this.currentUnit = canonical
    this.updateHelp()
  }

  canonicalUnit() {
    return this.indicatorTarget.selectedOptions[0]?.dataset.unit
  }

  toCanonical(indicator, value, unit) {
    if (indicator === "body_temperature" && unit === "°F") return ((value - 32) * 5) / 9

    const factor = UNIT_CONVERSIONS[indicator]?.[unit]
    return factor ? value * factor : value
  }

  fromCanonical(indicator, value, unit) {
    if (indicator === "body_temperature" && unit === "°F") return (value * 9) / 5 + 32

    const factor = UNIT_CONVERSIONS[indicator]?.[unit]
    return factor ? value / factor : value
  }

  formatNumber(value) {
    if (!Number.isFinite(value)) return ""
    return Number.isInteger(value) ? String(value) : value.toFixed(1)
  }

  updateHelp() {
    if (!this.hasHelpTarget || !this.hasIndicatorTarget || !this.hasUnitTarget) return

    const option = this.indicatorTarget.selectedOptions[0]
    if (!option) return

    const indicator = this.indicatorTarget.value
    const unit = this.unitTarget.value
    const expectedMin = parseFloat(option.dataset.expectedMin)
    const expectedMax = parseFloat(option.dataset.expectedMax)
    const plausibilityMin = parseFloat(option.dataset.plausibilityMin)
    const plausibilityMax = parseFloat(option.dataset.plausibilityMax)

    const display = (canonicalValue) => this.formatNumber(this.fromCanonical(indicator, canonicalValue, unit))
    const parts = []

    if (Number.isFinite(expectedMin) && Number.isFinite(expectedMax)) {
      parts.push(`Expected range: ${display(expectedMin)}–${display(expectedMax)} ${unit}`)
    }
    if (Number.isFinite(plausibilityMin) && Number.isFinite(plausibilityMax)) {
      parts.push(`Accepted: ${display(plausibilityMin)}–${display(plausibilityMax)} ${unit}`)
    }

    this.helpTarget.textContent = parts.join(" · ")
  }

  // Layer 1: reject impossible values before hitting the server.
  validatePlausibility() {
    const option = this.indicatorTarget.selectedOptions[0]
    const raw = parseFloat(this.valueTarget.value)
    if (!option || !Number.isFinite(raw)) return true

    const min = parseFloat(option.dataset.plausibilityMin)
    const max = parseFloat(option.dataset.plausibilityMax)
    const unit = this.unitTarget.value
    const label = option.textContent.replace(/\s*\([^)]*\)\s*$/, "").trim()

    if (Number.isFinite(min) && Number.isFinite(max) && (raw < min || raw > max)) {
      this.showValueError(
        `Invalid value. ${label} must be between ${this.formatNumber(min)} and ${this.formatNumber(max)} ${unit}. Please check the value and unit.`
      )
      return false
    }

    if (this.indicatorTarget.value === "mood_score" && !Number.isInteger(raw)) {
      this.showValueError("Mood must be a whole number between 1 and 10.")
      return false
    }

    this.clearValueError()
    return true
  }

  // Layer 2: ask for confirmation on extreme-but-possible values.
  confirmIfExtreme() {
    const option = this.indicatorTarget.selectedOptions[0]
    const raw = parseFloat(this.valueTarget.value)
    if (!option || !Number.isFinite(raw)) return true

    const low = parseFloat(option.dataset.confirmLow)
    const high = parseFloat(option.dataset.confirmHigh)
    const isLow = Number.isFinite(low) && raw < low
    const isHigh = Number.isFinite(high) && raw > high

    if (!isLow && !isHigh) {
      this.setConfirmed(false)
      return true
    }

    const direction = isLow ? "low" : "high"
    const baseline = this.hasBaselineTarget && this.baselineTarget.checked

    if (baseline) {
      const baselineMessage = "Baseline values should not be extreme. Please verify or enter a normal reference value."
      if (!window.confirm(`${baselineMessage} Continue anyway?`)) {
        this.setConfirmed(false)
        return false
      }
      if (!window.confirm(`This value is very ${direction}. Is it correct?`)) {
        this.setConfirmed(false)
        return false
      }
    } else if (!window.confirm(`This value is very ${direction}. Is it correct?`)) {
      this.setConfirmed(false)
      return false
    }

    this.setConfirmed(true)
    return true
  }

  setConfirmed(value) {
    if (this.hasConfirmedTarget) this.confirmedTarget.value = value ? "1" : "0"
  }

  async submit(event) {
    event.preventDefault()
    this.clearError()
    this.clearValueError()

    this.canonicalize()
    if (!this.validatePlausibility()) return
    if (!this.confirmIfExtreme()) return

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
        const errors = Array.isArray(data.errors) ? data.errors : []
        const valueError = errors.find((message) => /^Value/i.test(message))
        if (valueError) this.showValueError(valueError)

        const otherErrors = errors.filter((message) => message !== valueError)
        const message = otherErrors.length ? otherErrors.join(". ") : "Could not save the measurement."
        throw new Error(message)
      }

      document.dispatchEvent(new CustomEvent("health:reading-created", { detail: data }))
      this.showToast(data)
      this.formTarget.reset()
      this.setConfirmed(false)
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
      this.showError("Offline and local storage is unavailable.")
      return
    }

    offline.enqueue(this.formTarget)
    this.formTarget.reset()
    this.setConfirmed(false)
    this.updateUnit()
    this.close()
  }

  setBusy(busy) {
    if (!this.hasSubmitButtonTarget) return
    this.submitButtonTarget.disabled = busy
    this.submitButtonTarget.textContent = busy ? "Saving…" : "Save measurement"
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  showValueError(message) {
    if (!this.hasValueErrorTarget) return
    this.valueErrorTarget.textContent = message
    this.valueErrorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  clearValueError() {
    if (!this.hasValueErrorTarget) return
    this.valueErrorTarget.textContent = ""
    this.valueErrorTarget.classList.add("hidden")
  }

  showToast(data) {
    if (!this.hasToastTarget) return

    const reading = data.reading || {}
    const awards = data.awarded_achievements || []
    const warning = data.warning
    const statusLabel = { green: "Normal", yellow: "Follow-up", red: "Medical evaluation" }[reading.status] || reading.status

    this.toastTitleTarget.textContent = `Measurement saved: ${reading.label || "indicator"} = ${reading.value} ${reading.unit || ""}`
    const achievementText = awards.length
      ? `New achievement! ${awards.map((award) => `${award.name} (+${award.points} pts)`).join(", ")} · Total: ${data.total_points} pts`
      : `Status: ${statusLabel}. ${reading.recommendation?.text || ""}`

    this.toastBodyTarget.textContent = warning ? `${warning} ${achievementText}` : achievementText

    const tone = reading.status === "red" ? "rose" : warning ? "amber" : "emerald"
    this.toastTarget.classList.remove("hidden", ...ALL_TOAST_CLASSES)
    this.toastTarget.classList.add(...TOAST_TONES[tone])

    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => this.toastTarget.classList.add("hidden"), 6000)
  }
}
