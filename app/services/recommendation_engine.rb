# Genera una recomendación operativa concreta según el indicador y su semáforo.
# No sustituye el criterio médico: en rojo siempre se indica contactar al Flight Surgeon.
class RecommendationEngine
  # Acciones por indicador y status. El texto está pensado para leerse rápido
  # en un panel de cabina, con verbos de acción y pasos medibles.
  RECOMMENDATIONS = {
    "blood_pressure_systolic" => {
      "green" => "Mantener hidratación y rutina de ejercicio contra resistencia. Remedir en el próximo chequeo.",
      "yellow" => "Reposo 5 min, verificar manguito y remedir. Registrar segunda lectura. Evitar cafeína y esfuerzo.",
      "red" => "Reposo inmediato y remedir en 5 min. Si persiste > 140 o < 85 mmHg, contactar al Flight Surgeon."
    },
    "blood_pressure_diastolic" => {
      "green" => "Sin acción. Continuar monitorización diaria.",
      "yellow" => "Reposo 5 min y repetir medición con el brazo a la altura del corazón.",
      "red" => "Remedir tras 5 min de reposo. Si persiste >= 90 o < 50 mmHg, contactar al Flight Surgeon."
    },
    "heart_rate" => {
      "green" => "Sin acción. Mantener rutina cardiovascular y de sueño.",
      "yellow" => "Valorar estrés, hidratación y descanso. Reposo 5 min y remedir.",
      "red" => "Detener actividad, reposo y remedir. Si persiste > 130 o < 40 bpm o hay síntomas, contactar al Flight Surgeon."
    },
    "blood_glucose" => {
      "green" => "Mantener patrón de comidas y registrar tendencia.",
      "yellow" => "Revisar última ingesta y actividad. Remedir en 30 min. Si < 70 mg/dL, consumir 15 g de carbohidrato.",
      "red" => "Si < 54 mg/dL: tratar hipoglucemia de inmediato y avisar. Si >= 250 mg/dL: hidratación y contactar al Flight Surgeon."
    },
    "body_temperature" => {
      "green" => "Sin acción. Continuar monitorización.",
      "yellow" => "Hidratación, reposo y remedir en 30 min. Vigilar síntomas de infección.",
      "red" => "Activar protocolo de aislamiento si hay fiebre. Contactar al Flight Surgeon y monitorizar cada 30 min."
    },
    "sleep_hours" => {
      "green" => "Mantener horario de sueño y higiene del descanso.",
      "yellow" => "Priorizar una siesta de 20-30 min y reducir luz/estimulación antes del descanso.",
      "red" => "Déficit severo de sueño: suspender tareas críticas, informar al equipo y programar descanso obligatorio."
    },
    "mood_score" => {
      "green" => "Mantener rutina de contacto con familia y actividades de recuperación.",
      "yellow" => "Programar una conversación con el equipo y una actividad de recuperación. Registrar evolución.",
      "red" => "Riesgo psicosocial elevado: contactar al Flight Surgeon/psicólogo y activar protocolo de apoyo."
    },
    "reaction_time" => {
      "green" => "Rendimiento cognitivo dentro de rango. Repetir el test en el próximo chequeo.",
      "yellow" => "Fatiga cognitiva detectada. Se recomienda descanso (CIPHER / Spatial Cognition).",
      "red" => "Fatiga cognitiva marcada: suspender tareas críticas, descansar y repetir el test."
    },
    "meals_completed_percent" => {
      "green" => "Ingesta adecuada. Mantener el plan de comidas de la misión.",
      "yellow" => "Riesgo de Nutrición Inadecuada. Completar las comidas restantes y registrar la ingesta.",
      "red" => "Riesgo de Nutrición Inadecuada. Revisar el plan con el equipo y valorar suplementación."
    },
    "social_contact_minutes" => {
      "green" => "Contacto social adecuado. Mantener la rutina de interacción con la tripulación.",
      "yellow" => "Riesgo de Aislamiento (ARCHeR). Programar contacto con la tripulación y con Tierra.",
      "red" => "Aislamiento crítico: activar protocolo psicosocial y contacto inmediato con Tierra."
    }
  }.freeze

  attr_reader :reading

  def initialize(reading)
    @reading = reading
  end

  # Devuelve { text:, urgency:, escalate: }.
  # urgency: :routine | :watch | :urgent
  def call
    if baseline_deviation?
      return {
        text: HealthEvaluator::BASELINE_PROTOCOL,
        urgency: "watch",
        escalate: false
      }
    end

    text = RECOMMENDATIONS.dig(reading.indicator_type, reading.status) ||
           "Sin recomendación específica. Registrar y consultar al Flight Surgeon."

    {
      text: text,
      urgency: { "green" => "routine", "yellow" => "watch", "red" => "urgent" }.fetch(reading.status, "routine"),
      escalate: reading.status == "red"
    }
  end

  private

  def baseline_deviation?
    reading.status == "yellow" && HealthEvaluator.new(reading).baseline_deviation?
  end

  def self.for(reading)
    new(reading).call
  end
end
