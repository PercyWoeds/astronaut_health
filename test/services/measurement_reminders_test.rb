require "test_helper"

class MeasurementRemindersTest < ActiveSupport::TestCase
  setup do
    @mission = Mission.create!(name: "Reminders", code: "REM-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "Reminder Astronaut", mission: @mission)
    Indicator.seed_catalog!
  end

  test "sin lecturas todas las mediciones están pendientes" do
    pending = MeasurementReminders.call(@astronaut, day: Date.current)

    assert_equal HealthReading::INDICATOR_TYPES.sort, pending.sort
  end

  test "un indicador medido hoy deja de estar pendiente" do
    @astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 70, measured_at: Time.current
    )

    pending = MeasurementReminders.call(@astronaut, day: Date.current)

    assert_not_includes pending, "heart_rate"
    assert_includes pending, "blood_pressure_systolic"
  end

  test "un indicador diario medido ayer vuelve a estar pendiente" do
    @astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 70, measured_at: 1.day.ago
    )

    pending = MeasurementReminders.call(@astronaut, day: Date.current)

    assert_includes pending, "heart_rate"
  end

  test "un indicador semanal no está pendiente hasta cumplir la frecuencia" do
    Indicator.find_by(key: "reaction_time").update!(frequency_days: 7)
    @astronaut.health_readings.create!(
      indicator_type: "reaction_time", value: 350, measured_at: 2.days.ago
    )

    pending = MeasurementReminders.call(@astronaut, day: Date.current)

    assert_not_includes pending, "reaction_time"
  end
end
