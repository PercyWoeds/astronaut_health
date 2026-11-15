require "test_helper"

class HealthReadingsValidationTest < ActionDispatch::IntegrationTest
  setup do
    Indicator.seed_catalog!
    @mission = Mission.create!(name: "Validation UI", code: "VUI-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "Validation UI", mission: @mission)
  end

  test "new form renders unit options and expected range help" do
    get new_health_reading_path(mission_id: @mission.id, astronaut_id: @astronaut.id)

    assert_response :success
    assert_match "Blood glucose", response.body
    assert_match "mmol/L", response.body
    assert_match 'data-health-form-target="help"', response.body
  end

  test "confirmed extreme reading creates a critical alert and red status" do
    assert_difference -> { @astronaut.alerts.count }, 1 do
      post health_readings_path,
           params: {
             astronaut_id: @astronaut.id,
             health_reading: { indicator_type: "heart_rate", value: 200, unit: "bpm", confirmed: "1" }
           },
           as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "red", body["status"]
    assert body.dig("reading", "confirmed")
    assert_equal "action", @astronaut.alerts.order(:created_at).last.level
  end

  test "extreme reading without confirmation is rejected" do
    assert_no_difference -> { @astronaut.health_readings.count } do
      post health_readings_path,
           params: {
             astronaut_id: @astronaut.id,
             health_reading: { indicator_type: "heart_rate", value: 200, unit: "bpm" }
           },
           as: :json
    end

    assert_response :unprocessable_entity
    assert_match "Please confirm", response.body
  end

  test "clinically abnormal reading raises a watch alert" do
    assert_difference -> { @astronaut.alerts.count }, 1 do
      post health_readings_path,
           params: {
             astronaut_id: @astronaut.id,
             health_reading: { indicator_type: "heart_rate", value: 110, unit: "bpm" }
           },
           as: :json
    end

    assert_response :created
    alert = @astronaut.alerts.order(:created_at).last
    assert_equal "watch", alert.level
    assert_equal "absolute", alert.basis
  end

  test "critical anomaly raises an action alert" do
    assert_difference -> { @astronaut.alerts.count }, 1 do
      post health_readings_path,
           params: {
             astronaut_id: @astronaut.id,
             health_reading: { indicator_type: "heart_rate", value: 150, unit: "bpm" }
           },
           as: :json
    end

    assert_response :created
    assert_equal "action", @astronaut.alerts.order(:created_at).last.level
  end

  test "implausible reading is rejected with the accepted range" do
    assert_no_difference -> { @astronaut.health_readings.count } do
      post health_readings_path,
           params: {
             astronaut_id: @astronaut.id,
             health_reading: { indicator_type: "heart_rate", value: 400, unit: "bpm", confirmed: "1" }
           },
           as: :json
    end

    assert_response :unprocessable_entity
    assert_match "must be between 20 and 300 bpm", response.body
  end

  test "duplicate reading is saved with a warning" do
    @astronaut.health_readings.create!(indicator_type: "heart_rate", value: 75, measured_at: 2.minutes.ago)

    post health_readings_path,
         params: {
           astronaut_id: @astronaut.id,
           health_reading: { indicator_type: "heart_rate", value: 75, unit: "bpm" }
         },
         as: :json

    assert_response :created
    assert_match "very similar reading", JSON.parse(response.body)["warning"]
  end

  test "undo removes the last reading" do
    reading = @astronaut.health_readings.create!(indicator_type: "heart_rate", value: 75)

    assert_difference -> { @astronaut.health_readings.count }, -1 do
      delete health_reading_path(reading, mission_id: @mission.id, astronaut_id: @astronaut.id)
    end

    assert_redirected_to root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)
  end
end
