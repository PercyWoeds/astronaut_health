require "test_helper"

class HealthEvaluatorTest < ActiveSupport::TestCase
  def status_for(type, value)
    HealthEvaluator.new(HealthReading.new(indicator_type: type, value: value)).status
  end

  test "evalúa presión sistólica con umbrales AHA" do
    assert_equal "green", status_for("blood_pressure_systolic", 118)
    assert_equal "yellow", status_for("blood_pressure_systolic", 120)
    assert_equal "yellow", status_for("blood_pressure_systolic", 135)
    assert_equal "yellow", status_for("blood_pressure_systolic", 88)
    assert_equal "red", status_for("blood_pressure_systolic", 145)
    assert_equal "red", status_for("blood_pressure_systolic", 80)
  end

  test "clasifica la presión arterial según AHA" do
    assert_equal "Normal", HealthEvaluator.blood_pressure_category(118, 76)
    assert_equal "Elevated", HealthEvaluator.blood_pressure_category(124, 76)
    assert_equal "Stage 1 Hypertension", HealthEvaluator.blood_pressure_category(134, 82)
    assert_equal "Stage 2 Hypertension", HealthEvaluator.blood_pressure_category(145, 92)
    assert_equal "Hypertensive Crisis", HealthEvaluator.blood_pressure_category(185, 122)
  end

  test "evalúa presión diastólica" do
    assert_equal "green", status_for("blood_pressure_diastolic", 78)
    assert_equal "yellow", status_for("blood_pressure_diastolic", 85)
    assert_equal "red", status_for("blood_pressure_diastolic", 95)
  end

  test "evalúa frecuencia cardíaca" do
    assert_equal "green", status_for("heart_rate", 75)
    assert_equal "yellow", status_for("heart_rate", 45)
    assert_equal "yellow", status_for("heart_rate", 110)
    assert_equal "red", status_for("heart_rate", 35)
    assert_equal "red", status_for("heart_rate", 140)
  end

  test "evalúa glucosa" do
    assert_equal "green", status_for("blood_glucose", 100)
    assert_equal "yellow", status_for("blood_glucose", 60)
    assert_equal "red", status_for("blood_glucose", 50)
    assert_equal "red", status_for("blood_glucose", 260)
  end

  test "evalúa temperatura" do
    assert_equal "green", status_for("body_temperature", 36.8)
    assert_equal "yellow", status_for("body_temperature", 38.4)
    assert_equal "red", status_for("body_temperature", 39.2)
    assert_equal "red", status_for("body_temperature", 34.5)
  end

  test "evalúa sueño y estado de ánimo" do
    assert_equal "green", status_for("sleep_hours", 7)
    assert_equal "yellow", status_for("sleep_hours", 5)
    assert_equal "red", status_for("sleep_hours", 3)

    assert_equal "green", status_for("mood_score", 8)
    assert_equal "yellow", status_for("mood_score", 5)
    assert_equal "red", status_for("mood_score", 3)
  end

  def daily_check_with(attrs = {})
    DailyCheck.new({
      bone_density_loss_percent: 0.0,
      co2_level: 500,
      stress_level: 1,
      calories_intake: 2_500,
      vision_blurred: false,
      dizziness_reported: false,
      skin_rash: false
    }.merge(attrs))
  end

  test "visión borrosa activa alerta SANS y cabeza roja" do
    summary = HealthEvaluator.daily_check_summary(daily_check_with(vision_blurred: true))

    assert_equal "red", summary[:field_statuses]["vision_blurred"]
    assert_equal "red", summary[:zone_statuses]["head"]
    assert_equal HealthEvaluator::SANS_PROTOCOL, summary[:zone_indicators]["head"].first[:recommendation][:text]
  end

  test "mareo reportado deja el tórax en vigilancia" do
    summary = HealthEvaluator.daily_check_summary(daily_check_with(dizziness_reported: true))

    assert_equal "yellow", summary[:field_statuses]["dizziness_reported"]
    assert_equal "yellow", summary[:zone_statuses]["chest"]
  end

  test "estrés mayor de 7 marca la zona psicológica en rojo" do
    summary = HealthEvaluator.daily_check_summary(daily_check_with(stress_level: 8))

    assert_equal "red", summary[:field_statuses]["stress_level"]
    assert_equal "red", summary[:zone_statuses]["psychological"]
    assert_equal "red", summary[:zone_indicators]["psychological"].first[:status]
  end

  test "pérdida ósea mayor de 1.5 marca las extremidades en rojo" do
    summary = HealthEvaluator.daily_check_summary(daily_check_with(bone_density_loss_percent: 1.6))

    assert_equal "red", summary[:field_statuses]["bone_density_loss_percent"]
    assert_equal "red", summary[:zone_statuses]["limbs"]
  end

  test "CO2 usa los puntos de referencia de la ISS, no el umbral terrestre de cognición" do
    # 2.3 mmHg (~3,003 ppm) = first reported ISS symptoms.
    # 3.0 mmHg (~3,913 ppm) = ISS operational limit.
    # 5.3 mmHg (~6,913 ppm) = NASA 180-day SMAC.
    assert_equal "green", HealthEvaluator.daily_field_status("co2_level", 2_500)
    assert_equal "yellow", HealthEvaluator.daily_field_status("co2_level", 3_003)
    assert_equal "yellow", HealthEvaluator.daily_field_status("co2_level", 3_913)
    assert_equal "red", HealthEvaluator.daily_field_status("co2_level", 6_914)
  end

  test "convierte ppm a mmHg con el factor de referencia 1304.34" do
    assert_in_delta 2.3, HealthEvaluator.ppm_to_mmhg(3_000), 0.01
    assert_in_delta 3.0, HealthEvaluator.ppm_to_mmhg(3_913), 0.01
    assert_in_delta 5.3, HealthEvaluator.ppm_to_mmhg(6_913), 0.01
    assert_equal 3_000, HealthEvaluator.mmhg_to_ppm(2.3)
  end

  test "worst_status prioriza rojo sobre amarillo y verde" do
    assert_equal "red", HealthEvaluator.worst_status("green", "red", "yellow")
    assert_equal "yellow", HealthEvaluator.worst_status(nil, "green", "yellow")
    assert_equal "green", HealthEvaluator.worst_status(nil, "green")
  end

  def research_astronaut
    mission = Mission.create!(name: "Research Test", code: "RS-#{SecureRandom.hex(4)}")
    Astronaut.create!(name: "Research #{SecureRandom.hex(2)}", mission: mission)
  end

  test "OCT anormal activa SANS en cabeza con protocolo B-Complex" do
    assessment = ResearchAssessment.new(
      astronaut: research_astronaut,
      vision_test_performed: true,
      oct_scan_result: "abnormal"
    )

    summary = HealthEvaluator.research_summary(assessment)

    assert_equal "yellow", summary[:field_statuses]["oct_scan_result"]
    assert_equal "yellow", summary[:zone_statuses]["head"]
    assert summary[:zone_indicators]["head"].any? { |item| item[:recommendation][:text].include?("B-Complex") }
  end

  test "prueba visual vencida más de 7 días activa SANS" do
    astronaut = research_astronaut
    astronaut.research_assessments.create!(assessed_on: Date.current - 10.days, vision_test_performed: true)
    assessment = astronaut.research_assessments.create!(assessed_on: Date.current, vision_test_performed: false)

    summary = HealthEvaluator.research_summary(assessment)

    assert_equal "yellow", summary[:field_statuses]["vision_test_performed"]
    assert_equal "yellow", summary[:zone_statuses]["head"]
  end

  test "virus reactivation suspected activa alerta sistémica roja" do
    assessment = ResearchAssessment.new(
      astronaut: research_astronaut,
      virus_reactivation_suspected: true,
      vision_test_performed: true
    )

    summary = HealthEvaluator.research_summary(assessment)

    assert summary[:systemic_alert]
    assert_equal "red", summary[:zone_statuses]["immune"]
    assert_includes summary[:zone_indicators]["immune"].first[:recommendation][:text], "Houston"
  end

  test "calcio bajo y egress pendiente alertan sobre huesos" do
    astronaut = research_astronaut
    assessment = ResearchAssessment.new(
      astronaut: astronaut,
      calcium_isotopes_level: 7.8,
      vision_test_performed: true
    )
    pre_eva = PreEvaCheck.new(astronaut: astronaut, o2_ok: true, pressure_ok: true, fatigue_ok: true, egress_fitness_completed: false)

    summary = HealthEvaluator.research_summary(assessment, pre_eva_check: pre_eva)

    assert_equal "red", summary[:field_statuses]["calcium_isotopes_level"]
    assert_equal "yellow", summary[:field_statuses]["egress_fitness_completed"]
    assert_equal "red", summary[:zone_statuses]["limbs"]
    assert summary[:zone_indicators]["limbs"].any? { |item| item[:type] == "egress_fitness_completed" }
  end

  test "cognición baja y actigrafía sin sincronizar alertan en zona psicológica" do
    assessment = ResearchAssessment.new(
      astronaut: research_astronaut,
      vision_test_performed: true,
      cognitive_performance_survey_score: 35,
      actigraphy_device_synced: false
    )

    summary = HealthEvaluator.research_summary(assessment)

    assert_equal "yellow", summary[:field_statuses]["cognitive_performance_survey_score"]
    assert_equal "yellow", summary[:field_statuses]["actigraphy_device_synced"]
    assert_equal "yellow", summary[:zone_statuses]["psychological"]
    assert_includes summary[:zone_indicators]["psychological"].first[:recommendation][:text], "ARCHeR"
  end

  test "evalúa tiempo de reacción, comidas y contacto social" do
    assert_equal "green", status_for("reaction_time", 420)
    assert_equal "yellow", status_for("reaction_time", 620)
    assert_equal "red", status_for("reaction_time", 850)

    assert_equal "green", status_for("meals_completed_percent", 80)
    assert_equal "yellow", status_for("meals_completed_percent", 40)
    assert_equal "red", status_for("meals_completed_percent", 20)

    assert_equal "green", status_for("social_contact_minutes", 30)
    assert_equal "yellow", status_for("social_contact_minutes", 5)
    assert_equal "red", status_for("social_contact_minutes", 0)
  end

  test "una desviación mayor al 20% de la línea base escala de verde a amarillo" do
    astronaut = research_astronaut
    astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 60, is_baseline: true,
      measured_at: 8.days.ago
    )

    deviation = astronaut.health_readings.new(indicator_type: "heart_rate", value: 76, measured_at: Time.current)
    deviation.valid?

    assert deviation.is_a?(HealthReading)
    assert_equal "yellow", deviation.status
    assert HealthEvaluator.new(deviation).baseline_deviation?
    assert_equal HealthEvaluator::BASELINE_PROTOCOL, RecommendationEngine.for(deviation)[:text]

    within_range = astronaut.health_readings.new(indicator_type: "heart_rate", value: 65, measured_at: Time.current)
    within_range.valid?

    assert_equal "green", within_range.status
    refute HealthEvaluator.new(within_range).baseline_deviation?
  end

  test "el chequeo de síntomas marca cabeza y piel en rojo y tórax en amarillo" do
    check = SymptomCheck.new(rash_or_hives: true, vision_changes: true, dizziness_nausea: true)

    summary = HealthEvaluator.symptom_check_summary(check)

    assert_equal "red", summary[:field_statuses]["rash_or_hives"]
    assert_equal "red", summary[:field_statuses]["vision_changes"]
    assert_equal "yellow", summary[:field_statuses]["dizziness_nausea"]
    assert_equal "red", summary[:zone_statuses]["head"]
    assert_equal "red", summary[:zone_statuses]["immune"]
    assert_equal "yellow", summary[:zone_statuses]["chest"]
  end

  test "un valor extremo confirmado fuerza estado rojo y nota crítica" do
    astronaut = research_astronaut
    reading = astronaut.health_readings.new(indicator_type: "heart_rate", value: 200, confirmed: true)
    reading.valid?

    evaluator = HealthEvaluator.new(reading)

    assert evaluator.confirmed_extreme?
    assert_equal "red", evaluator.status
    assert_equal HealthEvaluator::CONFIRMED_EXTREME_NOTE, evaluator.explanation
    assert_equal "urgent", RecommendationEngine.for(reading)[:urgency]
  end

  test "un valor extremo sin confirmar no se marca como confirmado" do
    reading = HealthReading.new(indicator_type: "heart_rate", value: 200)

    refute HealthEvaluator.new(reading).confirmed_extreme?
  end
end
