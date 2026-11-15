import { Controller } from "@hotwired/stimulus"

const ENVIRONMENTS = {
  iss: {
    delay: "< 1 s",
    radiation: "Low",
    tone: "green",
    progress: 20,
    protocol: "One-way delay: < 1 s. Autonomous protocol active."
  },
  moon: {
    delay: "1.3 s",
    radiation: "Medium",
    tone: "yellow",
    progress: 50,
    protocol: "One-way delay: 1.3 s. Autonomous protocol active."
  },
  mars: {
    delay: "20 min",
    radiation: "High",
    tone: "red",
    progress: 85,
    protocol: "One-way delay: 20 min. Autonomous protocol active."
  }
}

const BADGE_TONES = {
  green: ["bg-emerald-500/15", "text-emerald-300", "border-emerald-500/40"],
  yellow: ["bg-amber-500/15", "text-amber-300", "border-amber-500/40"],
  red: ["bg-rose-500/15", "text-rose-300", "border-rose-500/40"]
}

const BAR_TONES = {
  green: ["bg-emerald-400"],
  yellow: ["bg-amber-400"],
  red: ["bg-rose-400"]
}

export default class extends Controller {
  static targets = ["select", "protocol", "delayNote"]

  connect() {
    this.apply(this.selectTarget.value)
  }

  change() {
    this.apply(this.selectTarget.value)
  }

  apply(key) {
    const environment = ENVIRONMENTS[key] || ENVIRONMENTS.iss

    this.updateDelay(environment)
    this.updateRadiation(environment)

    if (this.hasDelayNoteTarget) {
      this.delayNoteTarget.textContent = `Delay with Earth: ${environment.delay}`
    }

    if (this.hasProtocolTarget) {
      this.protocolTarget.textContent = environment.protocol
    }
  }

  updateDelay(environment) {
    const row = this.element.querySelector('[data-hrp-risk="distance"]')
    if (!row) return

    const value = row.querySelector("[data-hrp-value]")
    if (value) value.textContent = `Delay: ${environment.delay}`
  }

  updateRadiation(environment) {
    const row = this.element.querySelector('[data-hrp-risk="radiation"]')
    if (!row) return

    const badge = row.querySelector("[data-hrp-badge]")
    if (badge) {
      badge.textContent = environment.radiation
      this.swapTones(badge, BADGE_TONES, environment.tone)
    }

    const bar = row.querySelector("[data-hrp-bar]")
    if (bar) {
      bar.style.width = `${environment.progress}%`
      this.swapTones(bar, BAR_TONES, environment.tone)
    }
  }

  swapTones(element, palette, tone) {
    Object.values(palette).flat().forEach((className) => element.classList.remove(className))
    element.classList.add(...(palette[tone] || palette.green))
  }
}
