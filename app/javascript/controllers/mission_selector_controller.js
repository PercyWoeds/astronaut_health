import { Controller } from "@hotwired/stimulus"

// Al cambiar de misión se limpia el astronauta seleccionado y se recarga el
// dashboard para que el segundo selector muestre solo astronautas de esa misión.
export default class extends Controller {
  static targets = ["mission", "astronaut"]

  missionChanged() {
    if (this.hasAstronautTarget) this.astronautTarget.value = ""
    this.submit()
  }

  astronautChanged() {
    this.submit()
  }

  submit() {
    this.element.querySelector("form")?.requestSubmit()
  }
}
