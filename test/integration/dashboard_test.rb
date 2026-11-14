require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  setup do
    Indicator.seed_catalog!
    @mission = Mission.create!(name: "Dashboard", code: "DSH-#{SecureRandom.hex(4)}")
    @astronaut = Astronaut.create!(name: "Dashboard Astronaut", mission: @mission, destination: "iss")
    # Evita llamadas de red reales a DONKI durante los tests.
    SpaceWeatherService.provider = -> { [] }
  end

  teardown do
    SpaceWeatherService.reset_provider!
  end

  test "renderiza el dashboard y muestra el banner de mediciones pendientes" do
    get_dashboard

    assert_response :success
    assert_match "mediciones pendientes hoy", response.body
    assert_match "Retraso con la Tierra: 20 min", response.body
  end

  test "muestra las tarjetas de AI Flight Surgeon, Health Score y clima espacial" do
    get_dashboard

    assert_response :success
    assert_match "AI Flight Surgeon", response.body
    assert_match "Crew Health Score", response.body
    assert_match "Space Weather", response.body
    assert_match "All systems nominal", response.body
  end

  test "muestra el botón Reportar al Cirujano cuando hay una zona crítica" do
    @astronaut.health_readings.create!(
      indicator_type: "blood_pressure_systolic", value: 150, measured_at: Time.current
    )

    get_dashboard

    assert_response :success
    assert_match "Reportar al Cirujano", response.body
    assert_match "Systolic BP is elevated", response.body
  end

  private

  def get_dashboard
    get root_path(mission_id: @mission.id, astronaut_id: @astronaut.id)
  end
end
