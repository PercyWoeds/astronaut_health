import { Controller } from "@hotwired/stimulus"

// Renderiza la evolución de los últimos 7 registros por indicador con Chart.js.
// Chart.js se carga como script global desde el CDN en dashboard/index.html.erb.
export default class extends Controller {
  static targets = ["canvas", "select", "empty", "tableBody"]
  static values = { url: { type: String, default: "/api/health_readings/chart_data" } }

  connect() {
    this.chart = null
    this.datasets = []
    this.onReadingCreated = (event) => this.refresh(event.detail)
    document.addEventListener("health:reading-created", this.onReadingCreated)
    this.refresh()
  }

  disconnect() {
    document.removeEventListener("health:reading-created", this.onReadingCreated)
    this.chart?.destroy()
  }

  async refresh(newReading = null) {
    if (newReading) this.prependReadingRow(newReading)

    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const payload = await response.json()
      this.datasets = payload.datasets || []
      this.fillSelect()
      this.renderSelected()
    } catch (error) {
      console.error("No se pudo cargar chart_data", error)
      this.showEmpty(true)
    }
  }

  fillSelect() {
    const previous = this.selectTarget.value

    this.selectTarget.innerHTML = this.datasets
      .map((dataset) => `<option value="${dataset.indicatorType}">${this.escape(dataset.label)}</option>`)
      .join("")

    if (this.datasets.length === 0) {
      this.selectTarget.innerHTML = '<option value="">Sin datos</option>'
      return
    }

    const stillExists = this.datasets.some((dataset) => dataset.indicatorType === previous)
    this.selectTarget.value = stillExists ? previous : this.datasets[0].indicatorType
  }

  renderSelected() {
    const selectedType = this.selectTarget.value
    const dataset = this.datasets.find((item) => item.indicatorType === selectedType)

    if (!dataset || !window.Chart) {
      this.showEmpty(true)
      return
    }

    this.showEmpty(false)
    this.chart?.destroy()

    const statusColors = { green: "#34d399", yellow: "#fbbf24", red: "#fb7185" }
    const pointColors = dataset.statuses.map((status) => statusColors[status] || "#94a3b8")

    this.chart = new window.Chart(this.canvasTarget, {
      type: "line",
      data: {
        labels: dataset.labels,
        datasets: [{
          label: `${dataset.label} (${dataset.unit})`,
          data: dataset.data,
          borderColor: "#22d3ee",
          backgroundColor: "rgba(34, 211, 238, 0.12)",
          fill: true,
          tension: 0.35,
          borderWidth: 2,
          pointRadius: 5,
          pointHoverRadius: 7,
          pointBackgroundColor: pointColors,
          pointBorderColor: "#0f172a",
          pointBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 350 },
        plugins: {
          legend: {
            labels: { color: "#cbd5e1", font: { size: 12 } }
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.parsed.y} ${dataset.unit}`
            }
          }
        },
        scales: {
          x: {
            ticks: { color: "#94a3b8", maxRotation: 0 },
            grid: { color: "rgba(51, 65, 85, 0.45)" }
          },
          y: {
            ticks: { color: "#94a3b8" },
            grid: { color: "rgba(51, 65, 85, 0.45)" }
          }
        }
      }
    })
  }

  showEmpty(empty) {
    this.canvasTarget.classList.toggle("hidden", empty)
    this.emptyTarget.classList.toggle("hidden", !empty)
  }

  prependReadingRow(reading) {
    if (!this.hasTableBodyTarget) return

    const statusClasses = {
      green: "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
      yellow: "bg-amber-500/15 text-amber-300 border-amber-500/40",
      red: "bg-rose-500/15 text-rose-300 border-rose-500/40"
    }
    const dotClasses = { green: "bg-emerald-400", yellow: "bg-amber-400", red: "bg-rose-400" }
    const date = new Date(reading.measured_at)

    const row = document.createElement("tr")
    row.innerHTML = `
      <td class="py-2.5 pr-4 text-slate-300">${this.escape(reading.label)}</td>
      <td class="py-2.5 pr-4 font-medium text-slate-100">${reading.value} <span class="text-xs text-slate-500">${this.escape(reading.unit)}</span></td>
      <td class="py-2.5 pr-4">
        <span class="inline-flex items-center gap-1.5 rounded-full border px-2 py-0.5 text-[11px] font-semibold uppercase ${statusClasses[reading.status] || ""}">
          <span class="h-1.5 w-1.5 rounded-full ${dotClasses[reading.status] || "bg-slate-400"}"></span>${this.escape(reading.status)}
        </span>
      </td>
      <td class="py-2.5 text-slate-400">${date.toLocaleString("es-ES", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" })}</td>
    `
    this.tableBodyTarget.prepend(row)

    // Mantén como máximo 10 filas visibles.
    while (this.tableBodyTarget.children.length > 10) {
      this.tableBodyTarget.lastElementChild.remove()
    }
  }

  escape(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;")
  }
}
