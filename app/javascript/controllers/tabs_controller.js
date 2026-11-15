import { Controller } from "@hotwired/stimulus"

// Cambia entre pestañas sin recargar la página. No destruye el contenido
// oculto (el modelo 3D y sus data-targets siguen vivos en el DOM).
export default class extends Controller {
  static targets = ["tab", "content"]

  connect() {
    const initial = this.tabTargets.find((tab) => tab.getAttribute("aria-selected") === "true")
    this.show(initial?.dataset.tab || this.tabTargets[0]?.dataset.tab)
  }

  switch(event) {
    event.preventDefault()
    this.show(event.currentTarget.dataset.tab)
  }

  show(name) {
    if (!name) return

    this.contentTargets.forEach((content) => {
      content.classList.toggle("hidden", content.dataset.tab !== name)
    })

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tab === name

      tab.setAttribute("aria-selected", active ? "true" : "false")
      tab.classList.toggle("border-cyan-500", active)
      tab.classList.toggle("text-white", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("text-slate-400", !active)
    })
  }
}
