require "test_helper"

class HealthEvaluatorTest < ActiveSupport::TestCase
  def status_for(type, value)
    HealthEvaluator.new(HealthReading.new(indicator_type: type, value: value)).status
  end

  test "evalúa presión sistólica" do
    assert_equal "green", status_for("blood_pressure_systolic", 120)
    assert_equal "yellow", status_for("blood_pressure_systolic", 135)
    assert_equal "yellow", status_for("blood_pressure_systolic", 88)
    assert_equal "red", status_for("blood_pressure_systolic", 145)
    assert_equal "red", status_for("blood_pressure_systolic", 80)
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
end
