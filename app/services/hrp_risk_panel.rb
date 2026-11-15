# Panel de los 5 peligros oficiales del NASA Human Research Program (HRP).
#
# Traduce los indicadores de la app y el último chequeo diario (DailyCheck)
# a riesgos de misión. Usa los indicadores de los cinco peligros del HRP:
#   - Radiación (dosis simulada; estimación CSA de la fracción de neutrones).
#   - Pérdida de densidad ósea / osteoporosis acelerada y contramedidas.
#   - CO₂ en el entorno cerrado (ISS reference points).
#
# El resultado es un array de hashes listo para renderizar en la vista:
#   { key:, name:, icon:, value_label:, detail:, status:, progress:, note:, hint: }
# donde status es green/yellow/red/unknown y progress va de 0 a 100.
class HrpRiskPanel
  # Valores simulados de la misión. Ajústalos si quieres contar otra historia
  # en la demo (por ejemplo, una tormenta solar durante la presentación).
  # Simulated accumulated dose for the demo (NASA-STD-3001 career limit: 600 mSv).
  # Source: NASA OCHMO, "Standards overview" and "Radiation protection technical brief".
  RADIATION_DOSE_MSV = 18.6
  RADIATION_LIMIT_MSV = 600.0
  RADIATION_SOURCE = "NASA OCHMO, Standards overview (NASA-STD-3001, Vol. 1); " \
                     "NASA OCHMO, Radiation protection technical brief".freeze
  # Estimation from the Canadian Space Agency applied to the simulated dose.
  # It is NOT a measurement made by this app.
  NEUTRON_SHARE_PERCENT = 30
  NEUTRON_SOURCE = "CSA, Monitoring radiation for astronaut health, 2026-02-26 " \
                   "(asc-csa.gc.ca/eng/news/articles/2026/2026-02-26-monitoring-radiation-astronaut-health.asp)".freeze

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
  # CSA: ~30% de la dosis en la ISS corresponde a neutrones (estimación).
  def radiation_risk
    ratio = RADIATION_DOSE_MSV / RADIATION_LIMIT_MSV
    {
      key: "radiation",
      name: "Radiation",
      icon: "☢️",
      value_label: "Simulated dose #{format_number(RADIATION_DOSE_MSV)} mSv",
      detail: "Career limit: #{format_number(RADIATION_LIMIT_MSV)} mSv (NASA-STD-3001)",
      note: "Estimation: ~#{NEUTRON_SHARE_PERCENT}% of ISS radiation is neutrons (CSA).",
      hint: "Simulated accumulated dose, not measured. #{RADIATION_SOURCE}. #{NEUTRON_SOURCE}.",
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
        name: "Isolation / confinement",
        icon: "🧠",
        value_label: "Stress #{format_number(value)} / 10",
        detail: "Psychosocial risk · daily check",
        note: daily_check.stress_level > 7 ? "High stress: activate the psychosocial protocol." : nil,
        hint: nil,
        status: daily_field_status("stress_level"),
        progress: percent(value / 10.0)
      }
    end

    reading = readings["mood_score"]
    return unknown_risk("isolation", "Isolation / confinement", "🧠", "No mood data") unless reading

    value = reading.value.to_f
    {
      key: "isolation",
      name: "Isolation / confinement",
      icon: "🧠",
      value_label: "Mood #{format_number(value)} / 10",
      detail: "Psychosocial risk · HRP monitoring",
      note: nil,
      hint: nil,
      status: reading.status,
      progress: percent((10.0 - value) / 9.0)
    }
  end

  # 3. Distancia a la Tierra: retardo de comunicaciones (one-way) según destino.
  # ISS ~0 s (órbita baja), Luna ~1.3 s y Marte ~20 min.
  # Solo informativo: no cambia el estado de la zona.
  def distance_risk
    seconds = CommDelay.seconds_for(@astronaut)
    {
      key: "distance",
      name: "Distance to Earth",
      icon: "🛰️",
      value_label: "Delay: #{delay_label(seconds)}",
      detail: "One-way link with Houston · informative only",
      note: nil,
      hint: "Comm delay is informational. It does not change the health status.",
      status: "unknown",
      progress: 0
    }
  end

  # 4. Campos gravitatorios: pérdida de densidad ósea del chequeo diario.
  # Si no hay chequeo, cae a las horas de sueño (contramedida de carga).
  def gravity_risk
    if daily_check
      value = daily_check.bone_density_loss_percent.to_f
      return {
        key: "gravity",
        name: "Gravitational fields",
        icon: "🧲",
        value_label: "Bone loss #{format_number(value)} %",
        detail: "Microgravity · bone mass · entered from exam",
        note: "Accelerated osteoporosis risk. ISS/CSA data applicable on Earth.",
        hint: "Value entered from a medical exam (e.g., DEXA). The app does not measure bone density.",
        status: daily_field_status("bone_density_loss_percent"),
        progress: percent(value / 2.5)
      }
    end

    reading = readings["sleep_hours"]
    return unknown_risk("gravity", "Gravitational fields", "🧲", "No sleep hours data") unless reading

    value = reading.value.to_f
    {
      key: "gravity",
      name: "Gravitational fields",
      icon: "🧲",
      value_label: "Bone loss risk: ~1-2% monthly (NASA HRP).",
      detail: "Microgravity · bone mass loss",
      note: "Sleep logged: #{format_number(value)} h (load countermeasure proxy).",
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
      mmhg = HealthEvaluator.ppm_to_mmhg(value)
      return {
        key: "environment",
        name: "Closed environment",
        icon: "🌡️",
        value_label: "CO₂ #{value} ppm (~#{format("%.2f", mmhg)} mmHg)",
        detail: "Air quality · #{HealthEvaluator::CO2_REFERENCE_LABEL}",
        note: mmhg > HealthEvaluator::CO2_SMAC_180D_MMHG ?
              "Above NASA 180-day SMAC (5.3 mmHg, ~6,913 ppm)." :
              mmhg >= HealthEvaluator::CO2_OPERATING_LIMIT_MMHG ?
              "At/above the ISS operational limit (3.0 mmHg, ~3,913 ppm) — check ventilation." :
              nil,
        hint: "#{HealthEvaluator::CO2_SOURCE}. 2.3 mmHg: first symptoms reported by ISS crew.",
        status: daily_field_status("co2_level"),
        progress: percent(value / HealthEvaluator.mmhg_to_ppm(HealthEvaluator::CO2_SMAC_180D_MMHG).to_f)
      }
    end

    reading = readings["body_temperature"]
    return unknown_risk("environment", "Closed environment", "🌡️", "No body temperature data") unless reading

    value = reading.value.to_f
    {
      key: "environment",
      name: "Closed environment",
      icon: "🌡️",
      value_label: "#{format_number(value)} °C",
      detail: "Body temperature · infection risk",
      note: nil,
      hint: nil,
      status: reading.status,
      progress: percent((value - 37.0).abs / 3.0)
    }
  end

  def unknown_risk(key, name, icon, detail)
    { key: key, name: name, icon: icon, value_label: "No data", detail: detail, status: "unknown", progress: 0, note: nil, hint: nil }
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

  def delay_label(seconds)
    return "< 1 s" if seconds < 1
    return "#{format('%.1f', seconds)} s" if seconds < 60

    "#{(seconds / 60.0).round} min"
  end
end
