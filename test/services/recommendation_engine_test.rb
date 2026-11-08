require "test_helper"

class RecommendationEngineTest < ActiveSupport::TestCase
  test "un valor rojo escala al Flight Surgeon" do
    reading = HealthReading.new(indicator_type: "blood_pressure_systolic", value: 150, status: "red")
    result = RecommendationEngine.for(reading)

    assert_equal "urgent", result[:urgency]
    assert result[:escalate]
    assert_includes result[:text], "Flight Surgeon"
  end

  test "un valor verde es rutinario" do
    reading = HealthReading.new(indicator_type: "heart_rate", value: 70, status: "green")
    result = RecommendationEngine.for(reading)

    assert_equal "routine", result[:urgency]
    refute result[:escalate]
  end

  test "un valor amarillo queda en vigilancia" do
    reading = HealthReading.new(indicator_type: "sleep_hours", value: 5, status: "yellow")
    result = RecommendationEngine.for(reading)

    assert_equal "watch", result[:urgency]
    refute result[:escalate]
  end
end
