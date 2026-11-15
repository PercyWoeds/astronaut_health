# "AI Flight Surgeon": analiza las últimas 7 lecturas de HealthReading y genera
# recomendaciones operativas al estilo Mission Control, además de un score 0-100.
#
# Los indicadores reales del modelo son:
#   - "sleep_hours"              (horas de sueño)
#   - "mood_score"               (ánimo 1-10)
#   - "blood_pressure_systolic"  (presión sistólica mmHg)
#   - "blood_pressure_diastolic" (presión diastólica mmHg)
#   - "blood_glucose"            (glucosa mg/dL)
class AiFlightSurgeon
  SLEEP_THRESHOLD = 6.0
  MOOD_THRESHOLD = 4.0
  SYSTOLIC_THRESHOLD = 140
  READINGS_WINDOW = 7

  NOMINAL_RECOMMENDATION = "✅ All systems nominal. Continue routine monitoring.".freeze

  def initialize(astronaut, space_weather: nil)
    @astronaut = astronaut
    @space_weather = space_weather
  end

  # Array de strings con las recomendaciones. Si no hay alertas, devuelve la nominal.
  def generate_report
    recommendations = []
    recommendations << glucose_recommendation if glucose_critical?
    recommendations << sleep_recommendation if sleep_average && sleep_average < SLEEP_THRESHOLD
    recommendations << mood_recommendation if mood_average && mood_average < MOOD_THRESHOLD
    recommendations << systolic_recommendation if systolic_value && systolic_value > SYSTOLIC_THRESHOLD
    recommendations << diastolic_recommendation if diastolic_critical?
    recommendations << solar_recommendation if solar_events.any?

    recommendations.empty? ? [ NOMINAL_RECOMMENDATION ] : recommendations
  end

  # Health Score 0-100 según sueño, ánimo, glucosa, presión sistólica/diastólica
  # y clima espacial (alertas DONKI).
  def calculate_health_score
    score = 100
    score -= 20 if sleep_average && sleep_average < SLEEP_THRESHOLD
    score -= 20 if mood_average && mood_average < MOOD_THRESHOLD
    score -= 30 if glucose_critical?
    score -= 30 if systolic_value && systolic_value > SYSTOLIC_THRESHOLD
    score -= 30 if diastolic_critical?
    score -= 20 if solar_events.any?
    [ score, 0 ].max
  end
  alias health_score calculate_health_score

  # true si existe al menos una alerta (para pintar el borde rojo de la tarjeta).
  def critical?
    generate_report.any? { |recommendation| recommendation != NOMINAL_RECOMMENDATION }
  end

  def sleep_average
    average(recent_values("sleep_hours"))
  end

  def mood_average
    average(recent_values("mood_score"))
  end

  def systolic_value
    @systolic_value ||= @astronaut
      .health_readings
      .for_indicator("blood_pressure_systolic")
      .recent_first
      .first
      &.value
      &.to_f
  end

  # Última glucosa registrada. Crítica fuera de 54-250 mg/dL (ver HealthEvaluator::GLUCOSE).
  def glucose_value
    @glucose_value ||= @astronaut
      .health_readings
      .for_indicator("blood_glucose")
      .recent_first
      .first
      &.value
      &.to_f
  end

  def glucose_critical?
    range = HealthEvaluator::THRESHOLDS["blood_glucose"]
    glucose_value && (glucose_value >= range[:red_high] || glucose_value <= range[:red_low])
  end

  # Última presión diastólica registrada.
  def diastolic_value
    @diastolic_value ||= @astronaut
      .health_readings
      .for_indicator("blood_pressure_diastolic")
      .recent_first
      .first
      &.value
      &.to_f
  end

  # Crítica fuera de los límites rojos de HealthEvaluator::DIASTOLIC
  # (< 50 o >= 90 mmHg).
  def diastolic_critical?
    range = HealthEvaluator::THRESHOLDS["blood_pressure_diastolic"]
    diastolic_value && (diastolic_value >= range[:red_high] || diastolic_value <= range[:red_low])
  end

  # Eventos DONKI recientes. Se memoiza para no repetir la llamada HTTP.
  def solar_events
    @solar_events ||= Array(@space_weather || SpaceWeatherService.recent_solar_particles)
  end

  private

  attr_reader :astronaut

  def recent_values(indicator_type)
    @recent_values ||= {}
    @recent_values[indicator_type] ||= astronaut
      .health_readings
      .for_indicator(indicator_type)
      .recent_first
      .limit(READINGS_WINDOW)
      .map(&:value)
  end

  def average(values)
    return nil if values.blank?

    values.sum / values.length.to_f
  end

  def sleep_recommendation
    "⚠️ Sleep duration decreased to #{format_decimal(sleep_average)}h. " \
      "Elevated fatigue risk detected (ARCHeR). Recommendation: Prioritize 8h rest."
  end

  def mood_recommendation
    "⚠️ Mood Index is low (#{format_decimal(mood_average)}/10). " \
      "Isolation risk detected (NASA HRP). Recommendation: Schedule a video call with family."
  end

  def systolic_recommendation
    "❤️ Systolic BP is elevated (#{systolic_value.round} mmHg). " \
      "Cardiovascular adaptation risk. Recommendation: Rest 5 min, re-measure."
  end

  def diastolic_recommendation
    "❤️ Diastolic BP is critical (#{diastolic_value.round} mmHg). " \
      "Cardiovascular risk. Recommendation: Rest 5 min, re-measure and report if it persists."
  end

  def glucose_recommendation
    "🩸 Blood glucose is critical (#{glucose_value.round} mg/dL). " \
      "Metabolic risk. Recommendation: treat hypoglycemia/hyperglycemia and notify the Flight Surgeon."
  end

  def solar_recommendation
    "☢️ Recent Solar Particle Events detected. Radiation risk is HIGH. " \
      "Recommendation: Move to shielded sleep station."
  end

  def format_decimal(value)
    format("%.1f", value.to_f)
  end
end
