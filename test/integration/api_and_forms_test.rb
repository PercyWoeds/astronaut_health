require "test_helper"

class ApiEndpointsTest < ActionDispatch::IntegrationTest
  setup do
    Indicator.seed_catalog!
    @mission = Mission.create!(name: "API", code: "API-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "API Astronaut", mission: @mission, destination: "iss")
    @astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 72, measured_at: 1.hour.ago
    )
    SpaceWeatherService.provider = -> { [] }
  end

  teardown do
    SpaceWeatherService.reset_provider!
  end

  test "chart_data devuelve datasets listos para Chart.js" do
    get chart_data_api_health_readings_path, params: { mission_id: @mission.id, astronaut_id: @astronaut.id }

    assert_response :success
    body = JSON.parse(response.body)
    dataset = body["datasets"].find { |d| d["indicatorType"] == "heart_rate" }

    assert dataset.present?
    assert_equal [ 72 ], dataset["data"]
    assert_equal "bpm", dataset["unit"]
    assert dataset["labels"].present?
    assert dataset["reference_lines"].present?
  end

  test "health_readings index devuelve lecturas recientes" do
    get api_health_readings_path, params: { mission_id: @mission.id, astronaut_id: @astronaut.id }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.size
    assert_equal "heart_rate", body.first["indicator_type"]
    assert_equal "green", body.first["status"]
  end

  test "hrp_risks devuelve los riesgos del panel HRP" do
    get api_hrp_risks_path, params: { mission_id: @mission.id, astronaut_id: @astronaut.id }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["risks"].is_a?(Array)
    assert body["risks"].all? { |risk| risk["name"].present? }
  end

  test "health_status usa el primer astronauta si el id no pertenece a la misión" do
    get api_health_status_path, params: { mission_id: @mission.id, astronaut_id: 0 }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @astronaut.id, body.dig("astronaut", "id")
  end
end

class RemainingFormsTest < ActionDispatch::IntegrationTest
  setup do
    Indicator.seed_catalog!
    @mission = Mission.create!(name: "Forms", code: "FRM-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "Forms Astronaut", mission: @mission)
  end

  test "daily check guarda y actualiza el registro del día" do
    post daily_checks_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
         params: { daily_check: { bone_density_loss_percent: 1.5, co2_level: 2, stress_level: 3, calories_intake: 1800 } }

    assert_redirected_to root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)
    check = @astronaut.daily_checks.find_by(checked_on: Date.current)
    assert_equal 1.5, check.bone_density_loss_percent
    assert_equal 2, check.co2_level
  end

  test "research assessment guarda los estudios NASA" do
    post research_assessments_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
         params: { research_assessment: { saliva_sample_taken: "1", oct_scan_result: "normal", telomere_length: 8.2 } }

    assert_redirected_to root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)
    assessment = @astronaut.research_assessments.find_by(assessed_on: Date.current)
    assert assessment.saliva_sample_taken
    assert_equal "normal", assessment.oct_scan_result
  end

  test "biomarker sample rechaza notas demasiado largas" do
    assert_no_difference -> { @astronaut.biomarker_samples.count } do
      post biomarker_samples_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
           params: { biomarker_sample: { sample_type: "blood", notes: "x" * 1_001 } }
    end

    assert_redirected_to root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)
  end

  test "journal entry guarda el texto del diario" do
    post journal_entries_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
         params: { journal_entry: { content: "Good day, crew morale high." } }

    assert_redirected_to root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)
    assert_equal "Good day, crew morale high.", @astronaut.journal_entries.order(:id).last.content
  end

  test "pre-EVA incompleto no autoriza la actividad" do
    post pre_eva_checks_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
         params: { pre_eva_check: { o2_ok: "1", pressure_ok: "1", fatigue_ok: "0", egress_fitness_completed: "0" } }

    assert_redirected_to root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)
    follow_redirect!
    assert_match "Incomplete checklist", response.body
  end

  test "pre-EVA completo autoriza la actividad" do
    post pre_eva_checks_path(mission_id: @mission.id, astronaut_id: @astronaut.id),
         params: { pre_eva_check: { o2_ok: "1", pressure_ok: "1", fatigue_ok: "1", egress_fitness_completed: "1" } }

    assert_redirected_to root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)
    follow_redirect!
    assert_match "Activity authorized", response.body
  end
end
