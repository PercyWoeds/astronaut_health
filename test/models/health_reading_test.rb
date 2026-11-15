require "test_helper"

class HealthReadingTest < ActiveSupport::TestCase
  def astronaut
    @astronaut ||= begin
      mission = Mission.create!(name: "Validation Test", code: "VT-#{SecureRandom.hex(4)}")
      Astronaut.create!(name: "Validation #{SecureRandom.hex(2)}", mission: mission)
    end
  end

  def build_reading(type, value, **attrs)
    HealthReading.new({ astronaut: astronaut, indicator_type: type, value: value }.merge(attrs))
  end

  def assert_valid_value(type, value, **attrs)
    reading = build_reading(type, value, **attrs)
    assert reading.valid?, "expected #{type}=#{value} to be valid: #{reading.errors.full_messages.to_sentence}"
  end

  def assert_invalid_value(type, value, **attrs)
    reading = build_reading(type, value, **attrs)
    refute reading.valid?, "expected #{type}=#{value} to be invalid"
    reading
  end

  test "accepts the plausibility boundaries for every indicator" do
    boundaries = {
      "blood_pressure_systolic" => [ 30, 300 ],
      "blood_pressure_diastolic" => [ 20, 200 ],
      "heart_rate" => [ 20, 300 ],
      "blood_glucose" => [ 10, 1_000 ],
      "body_temperature" => [ 25, 45 ],
      "sleep_hours" => [ 0, 24 ],
      "mood_score" => [ 1, 10 ],
      "reaction_time" => [ 50, 10_000 ],
      "meals_completed_percent" => [ 0, 100 ],
      "social_contact_minutes" => [ 0, 1_440 ]
    }

    boundaries.each do |type, (min, max)|
      assert_valid_value(type, min, confirmed: true)
      assert_valid_value(type, max, confirmed: true)
    end
  end

  test "rejects values outside the plausibility range with a clear message" do
    invalid_values = {
      "blood_pressure_systolic" => [ 29, 301 ],
      "blood_pressure_diastolic" => [ 19, 201 ],
      "heart_rate" => [ 19, 301 ],
      "blood_glucose" => [ 9, 1_001 ],
      "body_temperature" => [ 24.9, 45.1 ],
      "sleep_hours" => [ -0.1, 24.1 ],
      "mood_score" => [ 0, 11 ],
      "reaction_time" => [ 49, 10_001 ],
      "meals_completed_percent" => [ -1, 101 ],
      "social_contact_minutes" => [ -1, 1_441 ]
    }

    invalid_values.each do |type, values|
      values.each do |value|
        reading = assert_invalid_value(type, value, confirmed: true)
        assert reading.errors[:value].any? { |message| message.include?("must be between") },
               "expected a plausibility error for #{type}=#{value}, got #{reading.errors.full_messages}"
      end
    end
  end

  test "mood must be a whole number" do
    reading = assert_invalid_value("mood_score", 5.5)

    assert_includes reading.errors[:value].to_s, "whole number"
  end

  test "extreme but possible values require confirmation" do
    extremes = {
      "blood_pressure_systolic" => [ 69, 201 ],
      "blood_pressure_diastolic" => [ 39, 131 ],
      "heart_rate" => [ 39, 181 ],
      "blood_glucose" => [ 53, 401 ],
      "body_temperature" => [ 34.9, 40.1 ],
      "sleep_hours" => [ nil, 12.1 ],
      "reaction_time" => [ nil, 2_001 ]
    }

    extremes.each do |type, values|
      values.compact.each do |value|
        reading = assert_invalid_value(type, value)
        assert reading.errors[:base].any? { |message| message.include?("Please confirm") },
               "expected a confirmation error for #{type}=#{value}, got #{reading.errors.full_messages}"
      end
    end
  end

  test "accepts extreme values once confirmed" do
    assert_valid_value("heart_rate", 181, confirmed: true)
    assert_valid_value("body_temperature", 40.1, confirmed: true)
    assert_valid_value("blood_glucose", 401, confirmed: true)
  end

  test "values at the confirmation boundary do not require confirmation" do
    assert_valid_value("blood_pressure_systolic", 70)
    assert_valid_value("blood_pressure_systolic", 200)
    assert_valid_value("heart_rate", 40)
    assert_valid_value("heart_rate", 180)
    assert_valid_value("blood_glucose", 54)
    assert_valid_value("blood_glucose", 400)
    assert_valid_value("body_temperature", 35)
    assert_valid_value("body_temperature", 40)
    assert_valid_value("sleep_hours", 12)
    assert_valid_value("reaction_time", 2_000)
  end

  test "converts mmol/L to the canonical mg/dL unit" do
    reading = build_reading("blood_glucose", 5.5, unit: "mmol/L")
    reading.valid?

    assert_in_delta 99.1, reading.value, 0.1
    assert_equal "mg/dL", reading.unit
  end

  test "converts Fahrenheit to the canonical Celsius unit" do
    reading = build_reading("body_temperature", 98.6, unit: "°F")
    reading.valid?

    assert_in_delta 37.0, reading.value, 0.1
    assert_equal "°C", reading.unit
  end

  test "converts kPa to the canonical mmHg unit" do
    reading = build_reading("blood_pressure_systolic", 16, unit: "kPa")
    reading.valid?

    assert_in_delta 120.0, reading.value, 0.1
    assert_equal "mmHg", reading.unit
  end

  test "rejects a unit that is not compatible with the indicator" do
    reading = assert_invalid_value("heart_rate", 75, unit: "kPa")

    assert reading.errors[:unit].any? { |message| message.include?("not compatible") }
  end

  test "diastolic pressure must be lower than the latest systolic pressure" do
    astronaut.health_readings.create!(
      indicator_type: "blood_pressure_systolic", value: 120, measured_at: 1.minute.ago
    )

    reading = assert_invalid_value("blood_pressure_diastolic", 125)

    assert reading.errors[:value].any? { |message| message.include?("lower than the latest systolic") }
  end

  test "rejects a measured_at in the future" do
    reading = assert_invalid_value("heart_rate", 75, measured_at: 1.hour.from_now)

    assert reading.errors[:measured_at].any? { |message| message.include?("can't be in the future") }
  end

  test "detects a duplicate reading from the previous 5 minutes" do
    astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 75, measured_at: 2.minutes.ago
    )

    reading = build_reading("heart_rate", 75, measured_at: Time.current)

    assert reading.duplicate_of_recent_reading.present?
  end

  test "does not flag a duplicate after 5 minutes" do
    astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 75, measured_at: 6.minutes.ago
    )

    reading = build_reading("heart_rate", 75, measured_at: Time.current)

    assert_nil reading.duplicate_of_recent_reading
  end

  test "exposes expected ranges and unit options for help text" do
    assert_equal 70.0..180.0, HealthReading.expected_range_for("blood_glucose")
    assert_equal %w[mg/dL mmol/L], HealthReading.unit_options_for("blood_glucose")
    assert_equal %w[mmHg kPa], HealthReading.unit_options_for("blood_pressure_systolic")
    assert_equal %w[°C °F], HealthReading.unit_options_for("body_temperature")
  end

  test "data origin defaults to manual and accepts the demo values" do
    reading = build_reading("heart_rate", 72)
    assert reading.valid?
    assert_equal "manual", reading.data_origin
    assert_equal "Manual entry", reading.data_origin_label

    reading = build_reading("heart_rate", 72, data_origin: "simulated")
    assert reading.valid?
    assert_equal "Simulated demo value", reading.data_origin_label
  end

  test "experimental hydration reading requires thirst score" do
    reading = build_reading("hydration_ml", 2500)
    assert_not reading.valid?
    assert_includes reading.errors.full_messages.to_sentence, "Thirst score"

    reading.thirst_score = 4
    assert reading.valid?
    assert_equal "Hydration (fluid intake)", reading.indicator_label
    assert_match(/\ALog total fluid intake in mL/, reading.measurement_guide)
  end

  test "experimental muscle reading is calculated from training minutes" do
    reading = build_reading(
      "muscle_performance", nil,
      resistance_minutes: 25, aerobic_minutes: 30,
      perceived_exertion: 6, muscle_soreness: 3
    )
    assert reading.valid?
    assert_equal 55.0, reading.value
    assert_equal "Calculated by the app", reading.data_origin_label if reading.data_origin == "calculated"
  end

  test "experimental muscle reading requires every training field" do
    reading = build_reading("muscle_performance", nil, resistance_minutes: 25)
    assert_not reading.valid?
    messages = reading.errors.full_messages.to_sentence
    assert_includes messages, "Aerobic"
    assert_includes messages, "Perceived exertion"
    assert_includes messages, "Muscle soreness"
  end

  test "external load forces device-recorded origin and must be complete" do
    reading = build_reading(
      "muscle_performance", 50,
      resistance_minutes: 20, aerobic_minutes: 30,
      perceived_exertion: 6, muscle_soreness: 3,
      external_load_kg: 40
    )
    assert_not reading.valid?
    assert_includes reading.errors.full_messages.to_sentence, "External load and reps"

    reading.external_reps = 12
    assert reading.valid?
    assert_equal "device-recorded", reading.data_origin
  end

  test "balance reading rejects unsafe tests and missing fields" do
    reading = build_reading("balance", 0, balance_episodes: 2, balance_test_performed: true)
    assert_not reading.valid?
    messages = reading.errors.full_messages.to_sentence
    assert_includes messages, "support"
    assert_includes messages, "environment"

    reading.balance_test_performed = false
    reading.balance_episodes = 3
    reading.balance_environment = "earth"
    assert reading.valid?

    reading.balance_test_performed = true
    reading.balance_test_supported = true
    reading.balance_environment = "moon"
    assert_not reading.valid?
    assert_includes reading.errors.full_messages.to_sentence, "reduced gravity"

    reading.balance_environment = "earth"
    reading.value = 4
    assert_not reading.valid?
    assert_includes reading.errors.full_messages.to_sentence, "symptoms"
  end
end
