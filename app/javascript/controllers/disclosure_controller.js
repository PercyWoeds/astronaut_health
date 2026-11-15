import { Controller } from "@hotwired/stimulus"

// Pequeño controlador reutilizable para paneles desplegables (Why?, síntomas).
export default class extends Controller {
  static targets = ["panel", "label"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.render()
  }

  toggle(event) {
    event.preventDefault()
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.render()
  }

  render() {
    this.panelTargets.forEach((panel) => panel.classList.toggle("hidden", !this.openValue))

    this.labelTargets.forEach((label) => {
      label.textContent = this.openValue
        ? (label.dataset.openLabel || "Hide")
        : (label.dataset.closedLabel || "View")
    })

    this.element.querySelectorAll("[data-disclosure-button]").forEach((button) => {
      button.setAttribute("aria-expanded", this.openValue ? "true" : "false")
    })
  }
}
