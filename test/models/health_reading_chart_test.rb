require "test_helper"

class HealthReadingChartTest < ActiveSupport::TestCase
  test "chart payload includes watch-zone reference lines and baseline" do
    mission = Mission.create!(name: "Chart Test", code: "CHT-#{SecureRandom.hex(4)}")
    astronaut = Astronaut.create!(name: "Chart Astronaut", mission: mission)

    astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 55, is_baseline: true,
      measured_at: 8.days.ago
    )
    astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 72, measured_at: 1.hour.ago
    )

    payload = HealthReading.chart_payload_for(astronaut)
    heart_rate = payload[:datasets].find { |item| item[:indicatorType] == "heart_rate" }

    assert_equal 55, heart_rate[:baseline]
    assert_equal({ lower: 50, upper: 100 }, heart_rate[:reference_lines])
  end

  test "experimental indicators have no reference lines" do
    mission = Mission.create!(name: "Chart Exp", code: "CHX-#{SecureRandom.hex(4)}")
    astronaut = Astronaut.create!(name: "Chart Exp", mission: mission)
    astronaut.health_readings.create!(
      indicator_type: "hydration_ml", value: 2000, thirst_score: 3,
      measured_at: 1.hour.ago
    )

    payload = HealthReading.chart_payload_for(astronaut)
    hydration = payload[:datasets].find { |item| item[:indicatorType] == "hydration_ml" }

    assert_nil hydration[:reference_lines]
    assert_nil hydration[:baseline]
  end
end
