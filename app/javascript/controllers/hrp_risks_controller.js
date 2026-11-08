import { Controller } from "@hotwired/stimulus"

// Refresca el panel "Riesgos de Misión (NASA HRP)" cuando se registra una
// medición nueva. El cálculo vive en HrpRiskPanel (Ruby); aquí solo pintamos
// el JSON que devuelve /api/hrp_risks.
const BAR_CLASSES = {
  green: ["bg-emerald-400"],
  yellow: ["bg-amber-400"],
  red: ["bg-rose-400"],
  unknown: ["bg-slate-500"]
}

const BADGE_CLASSES = {
  green: ["bg-emerald-500/15", "text-emerald-300", "border-emerald-500/40"],
  yellow: ["bg-amber-500/15", "text-amber-300", "border-amber-500/40"],
  red: ["bg-rose-500/15", "text-rose-300", "border-rose-500/40"],
  unknown: ["bg-slate-500/15", "text-slate-300", "border-slate-500/40"]
}

const STATUS_LABELS = {
  green: "Normal",
  yellow: "Vigilar",
  red: "Crítico",
  unknown: "Sin datos"
}

const ALL_BAR_CLASSES = Object.values(BAR_CLASSES).flat()
const ALL_BADGE_CLASSES = Object.values(BADGE_CLASSES).flat()

export default class extends Controller {
  static values = { url: { type: String, default: "/api/hrp_risks" } }

  connect() {
    this.onReadingCreated = () => this.refresh()
    document.addEventListener("health:reading-created", this.onReadingCreated)
  }

  disconnect() {
    document.removeEventListener("health:reading-created", this.onReadingCreated)
  }

  async refresh() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const payload = await response.json()
      ;(payload.risks || []).forEach((risk) => this.update(risk))
    } catch (error) {
      console.error("No se pudo actualizar el panel HRP", error)
    }
  }

  update(risk) {
    const row = this.element.querySelector(`[data-hrp-risk="${risk.key}"]`)
    if (!row) return

    const status = risk.status || "unknown"
    const bar = row.querySelector("[data-hrp-bar]")
    const badge = row.querySelector("[data-hrp-badge]")
    const value = row.querySelector("[data-hrp-value]")
    const detail = row.querySelector("[data-hrp-detail]")

    if (bar) {
      bar.style.width = `${risk.progress}%`
      bar.classList.remove(...ALL_BAR_CLASSES)
      bar.classList.add(...(BAR_CLASSES[status] || BAR_CLASSES.unknown))
    }

    if (badge) {
      badge.textContent = STATUS_LABELS[status] || status
      badge.classList.remove(...ALL_BADGE_CLASSES)
      badge.classList.add(...(BADGE_CLASSES[status] || BADGE_CLASSES.unknown))
    }

    if (value) value.textContent = risk.value_label
    if (detail) detail.textContent = risk.detail
  }
}
