require "test_helper"
class GroundReportsFlowTest < ActionDispatch::IntegrationTest
  setup do
    Indicator.seed_catalog!
    @mission = Mission.create!(name: "GR", code: "GR-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "GR Astro", mission: @mission, destination: "mars")
    @astronaut.health_readings.create!(indicator_type: "blood_pressure_systolic", value: 155, measured_at: Time.current)
  end

  test "crea un GroundReport desde el boton del cirujano" do
    assert_difference [ "GroundReport.count", "Alert.count" ], 1 do
      post ground_reports_path, params: { astronaut_id: @astronaut.id, summary: "Reporte de prueba" }
    end
    report = GroundReport.last
    assert_equal "sent", report.status
    assert_equal Date.current, report.sent_day
    assert report.earliest_reply_at.present?
    expected_delay = 2 * CommDelay.seconds_for(@astronaut)
    assert_in_delta report.created_at.to_f + expected_delay, report.earliest_reply_at.to_f, 2
    gr = report.alert
    assert_equal "mars", gr.astronaut.destination
  end
end
