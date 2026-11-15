require "test_helper"

class FlightStudyFlowsTest < ActionDispatch::IntegrationTest
  setup do
    @mission = Mission.create!(name: "Flight Study", code: "FS-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "Study Astronaut", mission: @mission)
  end

  test "guarda el chequeo de síntomas y redirige al dashboard" do
    post symptom_checks_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
         params: { symptom_check: { rash_or_hives: "1", vision_changes: "1", dizziness_nausea: "0" } }

    assert_redirected_to root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)
    check = @astronaut.symptom_checks.find_by(checked_on: Date.current)
    assert check.rash_or_hives
    assert check.vision_changes
    assert_not check.dizziness_nausea
  end

  test "guarda comidas y contacto social como lecturas de salud" do
    post wellness_checks_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
         params: { wellness_check: { meals_completed_percent: 40, social_contact_minutes: 5 } }

    assert_redirected_to root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)

    meals = @astronaut.health_readings.find_by(indicator_type: "meals_completed_percent")
    social = @astronaut.health_readings.find_by(indicator_type: "social_contact_minutes")

    assert_equal 40, meals.meals_completed_percent
    assert_equal "yellow", meals.status
    assert_equal 5, social.social_contact_minutes
    assert_equal "yellow", social.status
  end

  test "guarda el test de reacción y aplica el umbral de fatiga" do
    post health_readings_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
         params: { health_reading: { indicator_type: "reaction_time", value: 620, reaction_time_ms: 620 } },
         as: :json

    assert_response :created
    reading = @astronaut.health_readings.find_by(indicator_type: "reaction_time")

    assert_equal 620, reading.reaction_time_ms
    assert_equal "yellow", reading.status
  end

  test "una medición posterior compara con la baseline pre-vuelo" do
    @astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 60, is_baseline: true,
      measured_at: 8.days.ago
    )

    post health_readings_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
         params: { health_reading: { indicator_type: "heart_rate", value: 76 } },
         as: :json

    assert_response :created
    reading = @astronaut.health_readings.where(indicator_type: "heart_rate").recent_first.first

    assert_equal "yellow", reading.status
    assert_includes response.parsed_body.dig("recommendation", "text"), "pre-flight baseline"
  end
end
