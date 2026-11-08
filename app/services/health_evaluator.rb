# Servicio responsable de traducir un valor clínico a un semáforo green/yellow/red.
#
# Los umbrales son orientativos para monitorización de astronautas y están basados en:
#   - NASA Human Research Program (HRP): riesgos cardiovasculares, exposición a microgravedad
#     y contramedidas durante vuelos de larga duración.
#   - NASA-STD-3001 (NASA Space Flight Human-System Standard), Vol. 1: límites de salud.
#   - ESA Spaceflight Physiology / guías clínicas terrestres (ACC/AHA, OMS) cuando no existe
#     un estándar específico de vuelo espacial.
# En un contexto real, un Flight Surgeon debe validar y ajustar estos rangos por misión.
class HealthEvaluator
  # PRESIÓN ARTERIAL SISTÓLICA (mmHg)
  # > 140: riesgo cardiovascular y de remodelado arterial acelerado en microgravedad.
  # < 85: hipotensión/ortostatismo, especialmente relevante al retornar a 1g.
  SYSTOLIC = { red_low: 85, yellow_low: 90, yellow_high: 130, red_high: 140 }.freeze

  # PRESIÓN ARTERIAL DIASTÓLICA (mmHg)
  # >= 90 se asocia a hipertensión; < 50 puede indicar bajo gasto o deshidratación.
  DIASTOLIC = { red_low: 50, yellow_low: 60, yellow_high: 80, red_high: 90 }.freeze

  # FRECUENCIA CARDÍACA EN REPOSO (bpm)
  # La microgravedad reduce la carga cardíaca; taquicardia persistente > 100 puede reflejar
  # estrés, fiebre, arritmia o hipovolemia. Bradicardia < 40 es potencialmente sintomática.
  HEART_RATE = { red_low: 40, yellow_low: 50, yellow_high: 100, red_high: 130 }.freeze

  # GLUCOSA (mg/dL)
  # < 70 = hipoglucemia (riesgo de deterioro cognitivo en operaciones críticas).
  # >= 250 = hiperglucemia marcada; en vuelo puede agravarse por estrés y dieta.
  GLUCOSE = { red_low: 54, yellow_low: 70, yellow_high: 180, red_high: 250 }.freeze

  # TEMPERATURA CORPORAL (°C)
  # < 35.0 = hipotermia; >= 39.0 = fiebre alta. En entorno cerrado puede indicar infección.
  TEMPERATURE = { red_low: 35.0, yellow_low: 36.0, yellow_high: 38.0, red_high: 39.0 }.freeze

  # SUEÑO (horas en las últimas 24 h)
  # La NASA documenta ~6 h promedio en órbita, con déficit crónico y riesgo de fatiga.
  # < 4 h se considera crítico para la seguridad operacional.
  SLEEP = { red_low: 4.0, yellow_low: 6.0, yellow_high: 10.0, red_high: 12.0 }.freeze

  # ESTADO DE ÁNIMO (escala 1-10)
  # Herramienta de tamizaje del riesgo psicosocial (aislamiento/confinamiento).
  # <= 3 requiere intervención; 4-5 vigilancia activa.
  MOOD = { red_low: 4.0, yellow_low: 6.0 }.freeze

  THRESHOLDS = {
    "blood_pressure_systolic" => SYSTOLIC,
    "blood_pressure_diastolic" => DIASTOLIC,
    "heart_rate" => HEART_RATE,
    "blood_glucose" => GLUCOSE,
    "body_temperature" => TEMPERATURE,
    "sleep_hours" => SLEEP,
    "mood_score" => MOOD
  }.freeze

  attr_reader :reading, :value, :indicator_type

  def initialize(reading)
    @reading = reading
    @value = reading.value.to_f
    @indicator_type = reading.indicator_type
  end

  # Devuelve "green", "yellow" o "red". Si el indicador no tiene umbrales,
  # degrada a "green" para no bloquear la captura de datos.
  def status
    return "green" unless THRESHOLDS.key?(indicator_type)

    t = THRESHOLDS.fetch(indicator_type)

    return "red" if below_red?(t) || above_red?(t)
    return "yellow" if below_yellow?(t) || above_yellow?(t)

    "green"
  end

  # Explicación corta del resultado, útil para el panel lateral.
  def explanation
    case status
    when "red" then "Valor fuera del rango de seguridad operacional: requiere atención."
    when "yellow" then "Valor en zona de vigilancia: repetir medición y observar tendencia."
    else "Valor dentro del rango esperado para vuelo espacial."
    end
  end

  private

  def below_red?(t) = t[:red_low] && value < t[:red_low]
  def above_red?(t) = t[:red_high] && value >= t[:red_high]
  def below_yellow?(t) = t[:yellow_low] && value < t[:yellow_low]
  def above_yellow?(t) = t[:yellow_high] && value > t[:yellow_high]
end
