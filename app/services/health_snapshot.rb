# Construye el estado actual de salud del astronauta listo para serializar.
# Se usa tanto en el dashboard HTML como en /api/health_status, evitando
# duplicar la lógica de agregación de zonas y recomendaciones.
#
# Fusiona tres fuentes:
#   - HealthReading: series puntuales de signos vitales.
#   - DailyCheck: riesgos operativos NASA HRP / CSA.
#   - ResearchAssessment + PreEvaCheck: estudios Immune, CIPHER, SANS y ARCHeR.
class HealthSnapshot
  ZONE_NOTES = {
    "limbs" => "Accelerated osteoporosis risk. ISS (CSA) data helps prevent this on Earth."
  }.freeze

  PSYCHOLOGICAL_ZONE = {
    name: "psychological",
    description: "Psychological zone: isolation, confinement and mental workload during the mission."
  }.freeze

  # Indicadores que alimentan la zona psicológica virtual.
  PSYCHOLOGICAL_TYPES = %w[mood_score sleep_hours social_contact_minutes].freeze

  # Zona principal de cada indicador para mostrar cada alerta una sola vez.
  # El resto de zonas que lo rastrean lo muestran como etiqueta.
  PRIMARY_ZONE_OVERRIDES = {
    "mood_score" => "psychological",
    "social_contact_minutes" => "psychological",
    "sleep_hours" => "head"
  }.freeze

  IMMUNE_ZONE = {
    name: "immune",
    description: "Immune system and skin barriers: biomarkers, latent viruses and biological samples."
  }.freeze

  # Indicadores nuevos que se muestran en zonas existentes aunque la base de
  # datos ya tuviera los BodyZone creados antes de añadirlos al catálogo.
  EXTRA_ZONE_INDICATORS = {
    "head" => %w[reaction_time],
    "abdomen" => %w[meals_completed_percent]
  }.freeze

  attr_reader :astronaut, :daily_check, :research_assessment, :symptom_check, :pre_eva_check

  def initialize(astronaut)
    @astronaut = astronaut
    @daily_check = DailyCheck.latest_for(astronaut)
    @research_assessment = ResearchAssessment.latest_for(astronaut)
    @symptom_check = SymptomCheck.latest_for(astronaut)
    @pre_eva_check = astronaut&.pre_eva_checks&.recent_first&.first
  end

  def as_json
    {
      astronaut: astronaut_payload,
      overall_status: overall_status,
      main_action: main_action,
      zones: zones_payload,
      daily_check: daily_check_payload,
      research_assessment: research_payload,
      symptom_check: symptom_check_payload,
      generated_at: Time.current.iso8601
    }
  end

  def overall_status
    statuses = astronaut.health_readings.recent_first.to_a.filter_map(&:status)
    statuses.concat(Array(daily_evaluation&.dig(:zone_statuses)&.values))
    statuses.concat(Array(research_evaluation&.dig(:zone_statuses)&.values))
    statuses.concat(Array(symptom_evaluation&.dig(:zone_statuses)&.values))
    statuses << "red" if research_evaluation&.dig(:systemic_alert)
    %w[red yellow green].find { |candidate| statuses.include?(candidate) } || "green"
  end

  private

  def readings_by_type
    @readings_by_type ||= astronaut.latest_readings
  end

  def daily_evaluation
    @daily_evaluation ||= daily_check&.evaluation
  end

  def research_evaluation
    @research_evaluation ||= if research_assessment || pre_eva_check
      HealthEvaluator.research_summary(research_assessment, pre_eva_check: pre_eva_check)
    end
  end

  def symptom_evaluation
    @symptom_evaluation ||= symptom_check&.evaluation
  end

  def astronaut_payload
    {
      id: astronaut.id,
      name: astronaut.name,
      mission: astronaut.mission&.name,
      mission_code: astronaut.mission&.code,
      total_points: astronaut.total_points,
      achievements: astronaut.achievements.order(:name).map do |achievement|
        { id: achievement.id, name: achievement.name, description: achievement.description, points: achievement.points }
      end
    }
  end

  def daily_check_payload
    return nil unless daily_check

    {
      id: daily_check.id,
      checked_on: daily_check.checked_on.iso8601,
      bone_density_loss_percent: daily_check.bone_density_loss_percent,
      co2_level: daily_check.co2_level,
      stress_level: daily_check.stress_level,
      calories_intake: daily_check.calories_intake,
      vision_blurred: daily_check.vision_blurred,
      dizziness_reported: daily_check.dizziness_reported,
      skin_rash: daily_check.skin_rash
    }
  end

  def symptom_check_payload
    return nil unless symptom_check

    {
      id: symptom_check.id,
      checked_on: symptom_check.checked_on.iso8601,
      rash_or_hives: symptom_check.rash_or_hives,
      vision_changes: symptom_check.vision_changes,
      dizziness_nausea: symptom_check.dizziness_nausea
    }
  end

  def research_payload
    return nil unless research_assessment

    {
      id: research_assessment.id,
      assessed_on: research_assessment.assessed_on.iso8601,
      saliva_sample_taken: research_assessment.saliva_sample_taken,
      virus_reactivation_suspected: research_assessment.virus_reactivation_suspected,
      calcium_isotopes_level: research_assessment.calcium_isotopes_level,
      telomere_length: research_assessment.telomere_length,
      spatial_cognition_score: research_assessment.spatial_cognition_score,
      vestibular_test_passed: research_assessment.vestibular_test_passed,
      vision_test_performed: research_assessment.vision_test_performed,
      oct_scan_result: research_assessment.oct_scan_result,
      b_complex_supplement_taken: research_assessment.b_complex_supplement_taken,
      actigraphy_device_synced: research_assessment.actigraphy_device_synced,
      cognitive_performance_survey_score: research_assessment.cognitive_performance_survey_score
    }
  end

  # Acción principal: el dato crítico más reciente, o la vigilancia si solo
  # hay amarillo, o el estado nominal. Se muestra una sola vez arriba.
  def main_action
    red_items = all_zone_indicators.select { |item| item[:status] == "red" }
    yellow_items = all_zone_indicators.select { |item| item[:status] == "yellow" }

    if overall_status == "red" && red_items.any?
      worst = red_items.max_by { |item| item[:measured_at] }
      { tone: "red", title: alert_title(worst, "critical"), protocol: worst[:recommendation][:text], escalate: true }
    elsif overall_status == "yellow" && yellow_items.any?
      worst = yellow_items.max_by { |item| item[:measured_at] }
      { tone: "yellow", title: alert_title(worst, "under watch"), protocol: worst[:recommendation][:text], escalate: false }
    else
      {
        tone: "green",
        title: "All zones nominal",
        protocol: "Continue routine monitoring. Repeat the next scheduled measurement.",
        escalate: false
      }
    end
  end

  def zones_payload
    @zones_payload ||= build_zones_payload
  end

  private

  def all_zone_indicators
    zones_payload.flat_map { |zone| Array(zone[:indicators]) }
  end

  def alert_title(indicator, level)
    unit = indicator[:unit].to_s.presence
    value = unit ? "#{indicator[:value]} #{unit}" : indicator[:value]
    "#{indicator[:label]} #{value}: #{level}"
  end

  def primary_zone_by_indicator
    @primary_zone_by_indicator ||= begin
      map = {}
      BodyZone.order(:id).each do |zone|
        types = (Array(zone.related_indicators) + EXTRA_ZONE_INDICATORS.fetch(zone.name, [])).uniq
        types.each { |type| map[type] ||= zone.name }
      end
      PRIMARY_ZONE_OVERRIDES.each { |type, zone| map[type] = zone }
      map
    end
  end

  def build_zones_payload
    zones = BodyZone.order(:id).map do |zone|
      indicator_types = (Array(zone.related_indicators) + EXTRA_ZONE_INDICATORS.fetch(zone.name, [])).uniq
      extra_statuses = indicator_types.filter_map { |type| readings_by_type[type]&.status }
      base_status = HealthEvaluator.worst_status(zone.status_for(readings_by_type), *extra_statuses)
      build_zone(zone.name, zone.description, indicator_types, base_status: base_status)
    end

    psychological = psychological_zone_payload
    zones << psychological if psychological

    immune = immune_zone_payload
    zones << immune if immune

    zones
  end

  # Zona psicológica virtual (no tiene mesh propio en el cuerpo 3D).
  # Se alimenta del estrés (DailyCheck), ARCHeR y contacto social.
  def psychological_zone_payload
    daily_status = daily_evaluation&.dig(:zone_statuses, "psychological")
    research_status = research_evaluation&.dig(:zone_statuses, "psychological")
    has_reading = %w[mood_score sleep_hours social_contact_minutes].any? { |type| readings_by_type[type] }
    return nil unless daily_status || research_status || has_reading

    build_zone(
      PSYCHOLOGICAL_ZONE[:name],
      PSYCHOLOGICAL_ZONE[:description],
      %w[mood_score sleep_hours social_contact_minutes],
      base_status: nil
    )
  end

  # Zona inmune virtual: piel/sistema, virus latentes y biomarcadores.
  def immune_zone_payload
    return nil unless research_assessment || symptom_check

    build_zone(IMMUNE_ZONE[:name], IMMUNE_ZONE[:description], [], base_status: nil)
  end

  def build_zone(name, description, indicator_types, base_status:)
    primary_types = indicator_types.select { |type| primary_zone_by_indicator.fetch(type, name) == name }
    shared_types = indicator_types.reject { |type| primary_zone_by_indicator.fetch(type, name) == name }

    readings = primary_types.filter_map do |type|
      reading = readings_by_type[type]
      next unless reading

      {
        type: reading.indicator_type,
        label: reading.indicator_label,
        value: reading.value,
        unit: reading.unit,
        status: reading.status,
        measured_at: reading.measured_at.iso8601,
        category: blood_pressure_category(reading.indicator_type),
        baseline_note: reading.baseline_note,
        recommendation: RecommendationEngine.for(reading)
      }
    end

    shared_alerts = shared_types.filter_map do |type|
      reading = readings_by_type[type]
      next unless reading && %w[red yellow].include?(reading.status)

      {
        label: reading.indicator_label,
        value: reading.value,
        unit: reading.unit,
        status: reading.status,
        primary_zone: primary_zone_by_indicator.fetch(type, name)
      }
    end

    daily_indicators = Array(daily_evaluation&.dig(:zone_indicators, name))
    research_indicators = Array(research_evaluation&.dig(:zone_indicators, name))
    symptom_indicators = Array(symptom_evaluation&.dig(:zone_indicators, name))
    daily_status = daily_evaluation&.dig(:zone_statuses, name)
    research_status = research_evaluation&.dig(:zone_statuses, name)
    symptom_status = symptom_evaluation&.dig(:zone_statuses, name)
    systemic_alert = research_evaluation&.dig(:systemic_alert)

    status = HealthEvaluator.worst_status(base_status, daily_status, research_status, symptom_status)
    status = "red" if systemic_alert

    note_parts = [ ZONE_NOTES[name], research_evaluation&.dig(:notes, name) ]
    note_parts << research_evaluation&.dig(:notes, :all) if systemic_alert

    indicators = readings + daily_indicators + research_indicators + symptom_indicators
    indicators << systemic_indicator if systemic_alert

    {
      name: name,
      description: description,
      status: status,
      note: note_parts.compact.uniq.join(" ").presence,
      indicators: indicators,
      shared_alerts: shared_alerts
    }
  end

  # Categoría clínica AHA combinada (sistólica + diastólica) para presión arterial.
  def blood_pressure_category(indicator_type)
    return nil unless %w[blood_pressure_systolic blood_pressure_diastolic].include?(indicator_type)

    sys = readings_by_type["blood_pressure_systolic"]&.value
    dia = readings_by_type["blood_pressure_diastolic"]&.value
    return nil unless sys.present? && dia.present?

    HealthEvaluator.blood_pressure_category(sys, dia)
  end

  # Alerta inmune que se replica en todas las zonas: el protocolo indica
  # aislamiento y notificación inmediata a Houston.
  def systemic_indicator
    @systemic_indicator ||= {
      type: "systemic_immune_alert",
      label: "Systemic immune alert",
      value: "Suspected latent virus",
      unit: "",
      status: "red",
      measured_at: (research_assessment&.assessed_on&.to_time || Time.current).iso8601,
      recommendation: {
        text: HealthEvaluator::IMMUNE_PROTOCOL,
        urgency: "urgent",
        escalate: true
      }
    }
  end
end
