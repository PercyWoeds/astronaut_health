require "test_helper"

class RuleBasedFlightSurgeonTest < ActiveSupport::TestCase
  setup do
    @mission = Mission.create!(name: "AI Surgeon", code: "AI-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "AI Astronaut", mission: @mission)
  end

  test "sin lecturas y sin clima espacial es nominal con score 100" do
    surgeon = RuleBasedFlightSurgeon.new(@astronaut, space_weather: [])

    assert_equal [ RuleBasedFlightSurgeon::NOMINAL_RECOMMENDATION ], surgeon.generate_report
    assert_equal 100, surgeon.calculate_health_score
    assert_not surgeon.critical?
  end

  test "sueño bajo (últimas 7 lecturas) genera alerta y resta 20 puntos" do
    7.times do |index|
      @astronaut.health_readings.create!(
        indicator_type: "sleep_hours", value: 5, measured_at: index.days.ago
      )
    end

    surgeon = RuleBasedFlightSurgeon.new(@astronaut, space_weather: [])
    report = surgeon.generate_report

    assert(report.any? { |line| line.include?("Sleep duration decreased") })
    assert_equal 80, surgeon.calculate_health_score
    assert surgeon.critical?
  end

  test "ánimo bajo genera alerta y resta 20 puntos" do
    @astronaut.health_readings.create!(
      indicator_type: "mood_score", value: 3, measured_at: Time.current
    )

    surgeon = RuleBasedFlightSurgeon.new(@astronaut, space_weather: [])

    assert(surgeon.generate_report.any? { |line| line.include?("Mood Index is low") })
    assert_equal 80, surgeon.calculate_health_score
  end

  test "presión sistólica elevada genera alerta y resta 30 puntos" do
    @astronaut.health_readings.create!(
      indicator_type: "blood_pressure_systolic", value: 150, measured_at: Time.current
    )

    surgeon = RuleBasedFlightSurgeon.new(@astronaut, space_weather: [])

    assert(surgeon.generate_report.any? { |line| line.include?("Systolic BP is elevated") })
    assert_equal 70, surgeon.calculate_health_score
  end

  test "glucosa crítica genera alerta y resta 30 puntos" do
    @astronaut.health_readings.create!(
      indicator_type: "blood_glucose", value: 300, measured_at: Time.current
    )

    surgeon = RuleBasedFlightSurgeon.new(@astronaut, space_weather: [])

    assert(surgeon.generate_report.any? { |line| line.include?("Blood glucose is in the medical-evaluation range") })
    assert_equal 70, surgeon.calculate_health_score
  end

  test "presión diastólica crítica genera alerta y resta 30 puntos" do
    @astronaut.health_readings.create!(
      indicator_type: "blood_pressure_diastolic", value: 95, measured_at: Time.current
    )

    surgeon = RuleBasedFlightSurgeon.new(@astronaut, space_weather: [])

    assert(surgeon.generate_report.any? { |line| line.include?("Diastolic BP is in the medical-evaluation range") })
    assert_equal 70, surgeon.calculate_health_score
  end

  test "eventos solares generan alerta y restan 20 puntos" do
    surgeon = RuleBasedFlightSurgeon.new(@astronaut, space_weather: [ { "sepID" => "SEP-1" } ])

    assert(surgeon.generate_report.any? { |line| line.include?("DONKI reports recent Solar Particle Events") })
    assert_equal 80, surgeon.calculate_health_score
  end

  test "acumula todas las penalizaciones en el health score" do
    @astronaut.health_readings.create!(indicator_type: "sleep_hours", value: 5, measured_at: Time.current)
    @astronaut.health_readings.create!(indicator_type: "mood_score", value: 2, measured_at: Time.current)
    @astronaut.health_readings.create!(indicator_type: "blood_pressure_systolic", value: 160, measured_at: Time.current)

    surgeon = RuleBasedFlightSurgeon.new(@astronaut, space_weather: [ { "sepID" => "SEP-1" } ])

    assert_equal 10, surgeon.calculate_health_score
  end
end
