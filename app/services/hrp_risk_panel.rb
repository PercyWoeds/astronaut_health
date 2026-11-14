# Panel de los 5 peligros oficiales del NASA Human Research Program (HRP).
#
# Traduce los indicadores de la app y el último chequeo diario (DailyCheck)
# a riesgos de misión. Incluye el aporte de la Agencia Espacial Canadiense (CSA):
#   - Radiación de neutrones medida por el instrumento CANS (~30% del total en la ISS).
#   - Pérdida de densidad ósea / osteoporosis acelerada y contramedidas.
#   - CO₂ en el entorno cerrado.
#
# El resultado es un array de hashes listo para renderizar en la vista:
#   { key:, name:, icon:, value_label:, detail:, status:, progress:, note:, hint: }
# donde status es green/yellow/red/unknown y progress va de 0 a 100.
class HrpRiskPanel
  # Valores simulados de la misión. Ajústalos si quieres contar otra historia
  # en la demo (por ejemplo, una tormenta solar durante la presentación).
  RADIATION_DOSE_MSV = 18.6
  RADIATION_LIMIT_MSV = 150.0
  NEUTRON_DOSE_MSV = 5.5
  NEUTRON_SHARE_PERCENT = 30
  SIGNAL_DELAY_MINUTES = 20
  SIGNAL_DELAY_COMFORT_MINUTES = 40

  def initialize(astronaut)
    @astronaut = astronaut
    @readings = astronaut ? astronaut.latest_readings : {}
    @daily_check = DailyCheck.latest_for(astronaut)
    @daily_evaluation = @daily_check&.evaluation
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

  attr_reader :readings, :daily_check, :daily_evaluation

  def daily_field_status(field)
    daily_evaluation&.dig(:field_statuses, field)
  end

  # 1. Radiación: sin sensor real en el MVP, se simula dosis acumulada.
  # CSA/CANS: ~30% de la dosis en la ISS corresponde a neutrones.
  def radiation_risk
    ratio = RADIATION_DOSE_MSV / RADIATION_LIMIT_MSV
    {
      key: "radiation",
      name: "Radiación",
      icon: "☢️",
      value_label: "#{format_number(RADIATION_DOSE_MSV)} / #{format_number(RADIATION_LIMIT_MSV)} mSv",
      detail: "Dosis acumulada estimada (simulada)",
      note: "Incluye ~#{format_number(NEUTRON_DOSE_MSV)} mSv de neutrones (CSA/CANS)",
      hint: "Aproximadamente el #{NEUTRON_SHARE_PERCENT}% de la radiación en la ISS es de neutrones (CSA/CANS).",
      status: status_for_ratio(ratio, yellow_at: 0.5, red_at: 0.8),
      progress: percent(ratio)
    }
  end

  # 2. Aislamiento/confinamiento: estrés del chequeo diario o, si no existe,
  # el estado de ánimo (1-10). Cuanto mayor el estrés, mayor el riesgo.
  def isolation_risk
    if daily_check
      value = daily_check.stress_level.to_f
      return {
        key: "isolation",
        name: "Aislamiento / confinamiento",
        icon: "🧠",
        value_label: "Estrés #{format_number(value)} / 10",
        detail: "Riesgo psicosocial · chequeo diario",
        note: daily_check.stress_level > 7 ? "Estrés elevado: activar protocolo psicosocial." : nil,
        hint: nil,
        status: daily_field_status("stress_level"),
        progress: percent(value / 10.0)
      }
    end

    reading = readings["mood_score"]
    return unknown_risk("isolation", "Aislamiento / confinamiento", "🧠", "Sin dato de estado de ánimo") unless reading

    value = reading.value.to_f
    {
      key: "isolation",
      name: "Aislamiento / confinamiento",
      icon: "🧠",
      value_label: "Ánimo #{format_number(value)} / 10",
      detail: "Riesgo psicosocial · seguimiento HRP",
      note: nil,
      hint: nil,
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
      note: nil,
      hint: nil,
      status: status_for_ratio(ratio, yellow_at: 0.5, red_at: 0.85),
      progress: percent(ratio)
    }
  end

  # 4. Campos gravitatorios: pérdida de densidad ósea del chequeo diario.
  # Si no hay chequeo, cae a las horas de sueño (contramedida de carga).
  def gravity_risk
    if daily_check
      value = daily_check.bone_density_loss_percent.to_f
      return {
        key: "gravity",
        name: "Campos gravitatorios",
        icon: "🧲",
        value_label: "Pérdida ósea #{format_number(value)} %",
        detail: "Microgravedad · masa ósea",
        note: "Riesgo de osteoporosis acelerada. Datos ISS/CSA aplicables en Tierra.",
        hint: nil,
        status: daily_field_status("bone_density_loss_percent"),
        progress: percent(value / 2.5)
      }
    end

    reading = readings["sleep_hours"]
    return unknown_risk("gravity", "Campos gravitatorios", "🧲", "Sin dato de horas de sueño") unless reading

    value = reading.value.to_f
    {
      key: "gravity",
      name: "Campos gravitatorios",
      icon: "🧲",
      value_label: "#{format_number(value)} h de sueño",
      detail: "Microgravedad · pérdida de masa ósea",
      note: nil,
      hint: nil,
      status: reading.status,
      progress: percent((8.0 - value) / 8.0)
    }
  end

  # 5. Entorno cerrado: CO₂ del chequeo diario. Si no hay chequeo,
  # cae a la temperatura corporal (riesgo de infección).
  def closed_environment_risk
    if daily_check
      value = daily_check.co2_level.to_i
      return {
        key: "environment",
        name: "Entorno cerrado",
        icon: "🌡️",
        value_label: "CO₂ #{value} ppm",
        detail: "Calidad de aire · módulo presurizado",
        note: value > 1_000 ? "CO₂ por encima del objetivo. Revisar ventilación y filtros." : nil,
        hint: nil,
        status: daily_field_status("co2_level"),
        progress: percent(value / 3_000.0)
      }
    end

    reading = readings["body_temperature"]
    return unknown_risk("environment", "Entorno cerrado", "🌡️", "Sin dato de temperatura corporal") unless reading

    value = reading.value.to_f
    {
      key: "environment",
      name: "Entorno cerrado",
      icon: "🌡️",
      value_label: "#{format_number(value)} °C",
      detail: "Temperatura corporal · riesgo de infección",
      note: nil,
      hint: nil,
      status: reading.status,
      progress: percent((value - 37.0).abs / 3.0)
    }
  end

  def unknown_risk(key, name, icon, detail)
    { key: key, name: name, icon: icon, value_label: "Sin datos", detail: detail, status: "unknown", progress: 0, note: nil, hint: nil }
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
