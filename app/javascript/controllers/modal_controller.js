import { Controller } from "@hotwired/stimulus"

// Modal genérico para chequeo diario, diario de a bordo y checklist pre-EVA.
// El elemento del controlador envuelve el botón de apertura y el overlay.
export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this.onKeydown = (event) => {
      if (event.key === "Escape" && this.isOpen) this.close()
    }
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  get isOpen() {
    return !this.modalTarget.classList.contains("hidden")
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    setTimeout(() => {
      this.modalTarget.querySelector("textarea, input:not([type='hidden']), select")?.focus()
    }, 50)
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }
}