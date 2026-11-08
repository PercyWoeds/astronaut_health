# Panel de los 5 peligros oficiales del NASA Human Research Program (HRP).
#
# Traduce los indicadores que ya monitoriza la app (ánimo, sueño y temperatura)
# a riesgos de misión. Radiación y distancia a la Tierra usan valores simulados
# de misión porque el MVP no recibe telemetría de esos subsistemas.
#
# El resultado es un array de hashes listo para renderizar en la vista:
#   { key:, name:, icon:, value_label:, detail:, status:, progress: }
# donde status es green/yellow/red/unknown y progress va de 0 a 100.
class HrpRiskPanel
  # Valores simulados de la misión. Ajústalos si quieres contar otra historia
  # en la demo (por ejemplo, una tormenta solar durante la presentación).
  RADIATION_DOSE_MSV = 18.6
  RADIATION_LIMIT_MSV = 150.0
  SIGNAL_DELAY_MINUTES = 20
  SIGNAL_DELAY_COMFORT_MINUTES = 40

  def initialize(astronaut)
    @astronaut = astronaut
    @readings = astronaut ? astronaut.latest_readings : {}
  end

  def as_json
    [
      radiation_risk,
      isolation_risk,
      distance_risk,
      gravity_risk,
      closed_environment_risk
    ]
  end

  private

  attr_reader :readings

  # 1. Radiación: sin sensor real en el MVP, se simula dosis acumulada.
  def radiation_risk
    ratio = RADIATION_DOSE_MSV / RADIATION_LIMIT_MSV
    {
      key: "radiation",
      name: "Radiación",
      icon: "☢️",
      value_label: "#{format_number(RADIATION_DOSE_MSV)} / #{format_number(RADIATION_LIMIT_MSV)} mSv",
      detail: "Dosis acumulada estimada (simulada)",
      status: status_for_ratio(ratio, yellow_at: 0.5, red_at: 0.8),
      progress: percent(ratio)
    }
  end

  # 2. Aislamiento/confinamiento: se mapea al estado de ánimo (1-10).
  # Cuanto menor es el ánimo, mayor es el riesgo psicosocial.
  def isolation_risk
    reading = readings["mood_score"]
    return unknown_risk("isolation", "Aislamiento / confinamiento", "🧠", "Sin dato de estado de ánimo") unless reading

    value = reading.value.to_f
    {
      key: "isolation",
      name: "Aislamiento / confinamiento",
      icon: "🧠",
      value_label: "Ánimo #{format_number(value)} / 10",
      detail: "Riesgo psicosocial · seguimiento HRP",
      status: reading.status,
      progress: percent((10.0 - value) / 9.0)
    }
  end

  # 3. Distancia a la Tierra: retardo de comunicaciones simulado.
  def distance_risk
    ratio = SIGNAL_DELAY_MINUTES.to_f / SIGNAL_DELAY_COMFORT_MINUTES
    {
      key: "distance",
      name: "Distancia a la Tierra",
      icon: "🛰️",
      value_label: "Retraso: #{SIGNAL_DELAY_MINUTES} min",
      detail: "Enlace unidireccional con Houston",
      status: status_for_ratio(ratio, yellow_at: 0.5, red_at: 0.85),
      progress: percent(ratio)
    }
  end

  # 4. Campos gravitatorios: se mapea a horas de sueño (contramedida de carga).
  # Dormir menos de lo recomendado eleva el riesgo de fatiga y pérdida ósea.
  def gravity_risk
    reading = readings["sleep_hours"]
    return unknown_risk("gravity", "Campos gravitatorios", "🧲", "Sin dato de horas de sueño") unless reading

    value = reading.value.to_f
    {
      key: "gravity",
      name: "Campos gravitatorios",
      icon: "🧲",
      value_label: "#{format_number(value)} h de sueño",
      detail: "Microgravedad · pérdida de masa ósea",
      status: reading.status,
      progress: percent((8.0 - value) / 8.0)
    }
  end

  # 5. Entorno cerrado: se mapea a temperatura corporal (riesgo de infección).
  # La barra crece según la desviación respecto a 37 °C.
  def closed_environment_risk
    reading = readings["body_temperature"]
    return unknown_risk("environment", "Entorno cerrado", "🌡️", "Sin dato de temperatura corporal") unless reading

    value = reading.value.to_f
    {
      key: "environment",
      name: "Entorno cerrado",
      icon: "🌡️",
      value_label: "#{format_number(value)} °C",
      detail: "Temperatura corporal · riesgo de infección",
      status: reading.status,
      progress: percent((value - 37.0).abs / 3.0)
    }
  end

  def unknown_risk(key, name, icon, detail)
    { key: key, name: name, icon: icon, value_label: "Sin datos", detail: detail, status: "unknown", progress: 0 }
  end

  def status_for_ratio(ratio, yellow_at:, red_at:)
    return "red" if ratio >= red_at
    return "yellow" if ratio >= yellow_at

    "green"
  end

  def percent(ratio)
    (ratio * 100).round.clamp(0, 100)
  end

  def format_number(value)
    value.to_f % 1 == 0 ? value.to_i.to_s : format("%.1f", value)
  end
end
