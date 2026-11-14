import { Controller } from "@hotwired/stimulus"

// Sincroniza el valor visible de un slider con su input range.
export default class extends Controller {
  static targets = ["input", "output"]

  connect() {
    this.update()
  }

  update() {
    if (!this.hasInputTarget || !this.hasOutputTarget) return

    this.outputTarget.textContent = `${this.inputTarget.value}${this.inputTarget.dataset.suffix || ""}`
  }
}