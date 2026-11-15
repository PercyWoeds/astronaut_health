require "test_helper"

class GamificationServiceTest < ActiveSupport::TestCase
  setup do
    mission = Mission.create!(name: "Test Mission", code: "TEST-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "Test Astronaut", mission: mission)
  end

  def complete_day!(date)
    {
      blood_pressure_systolic: 118,
      blood_pressure_diastolic: 78,
      heart_rate: 70,
      blood_glucose: 100,
      body_temperature: 36.8,
      sleep_hours: 7,
      mood_score: 8
    }.each_with_index do |(type, value), index|
      @astronaut.health_readings.create!(
        indicator_type: type.to_s,
        value: value,
        measured_at: date.beginning_of_day + 8.hours + index.minutes
      )
    end
  end

  test "otorga chequeo diario y día en verde al completar todos los indicadores" do
    complete_day!(Time.zone.today)
    awarded = GamificationService.new(@astronaut).call

    names = awarded.map(&:name)
    assert_includes names, "First reading"
    assert_includes names, "Complete daily check"
    assert_includes names, "Green day"
    assert_equal 135, @astronaut.reload.total_points
  end

  test "es idempotente y otorga racha de 3 días" do
    complete_day!(Time.zone.today)
    GamificationService.new(@astronaut).call
    assert_empty GamificationService.new(@astronaut).call

    complete_day!(Time.zone.yesterday)
    complete_day!(2.days.ago)
    awarded = GamificationService.new(@astronaut).call

    assert_equal [ "3-day streak" ], awarded.map(&:name)
    assert_equal 235, @astronaut.reload.total_points
  end
end
