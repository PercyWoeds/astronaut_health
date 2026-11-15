import { Controller } from "@hotwired/stimulus"

// Delay values come from CommDelay (server) so the demo and the published app
// use the same reference text. Communication delay is informational only: it
// never changes a health status or turns a zone into Follow-up.
const FALLBACK = {
  iss: {
    delay: "< 1 s (simulated low-latency link)",
    protocol: "One-way delay: < 1 s (simulated low-latency link). Autonomous protocol active. Communication delay is informational and does not change the health status."
  },
  moon: {
    delay: "≈ 1.3 s",
    protocol: "One-way delay: ≈ 1.3 s. Autonomous protocol active. Communication delay is informational and does not change the health status."
  },
  mars: {
    delay: "11 min 22 s (demo value; real range: a few minutes to more than 20 min)",
    protocol: "One-way delay: 11 min 22 s (demo value). Autonomous protocol active. Communication delay is informational and does not change the health status."
  }
}

export default class extends Controller {
  static targets = ["select", "protocol", "delayNote"]
  static values = { delays: { type: Object, default: {} } }

  connect() {
    this.apply(this.selectTarget.value)
  }

  change() {
    this.apply(this.selectTarget.value)
  }

  apply(key) {
    const environment = this.delaysValue[key] || FALLBACK[key] || FALLBACK.iss

    this.updateDelay(environment)

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
}
