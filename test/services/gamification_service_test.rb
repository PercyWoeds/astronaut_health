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
      measured_at = date.beginning_of_day + 8.hours + index.minutes
      measured_at = Time.current - 1.minute if measured_at > Time.current
      @astronaut.health_readings.create!(
        indicator_type: type.to_s,
        value: value,
        measured_at: measured_at
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

  test "otorga logros por indicadores experimentales del día" do
    today_early = [ Date.current.beginning_of_day + 1.hour, Time.current - 1.minute ].min
    @astronaut.health_readings.create!(
      indicator_type: "hydration_ml", value: 2400, thirst_score: 3,
      data_origin: "simulated", measured_at: today_early
    )
    @astronaut.health_readings.create!(
      indicator_type: "muscle_performance", value: 50,
      resistance_minutes: 20, aerobic_minutes: 30,
      perceived_exertion: 5, muscle_soreness: 1,
      data_origin: "simulated", measured_at: today_early
    )
    @astronaut.health_readings.create!(
      indicator_type: "balance", value: 0, balance_episodes: 1,
      balance_environment: "earth", data_origin: "simulated", measured_at: today_early
    )

    awarded = GamificationService.new(@astronaut).call.map(&:name)

    assert_includes awarded, "Hydration logged"
    assert_includes awarded, "Training logged"
    assert_includes awarded, "Balance self-check logged"
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
