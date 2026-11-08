require "test_helper"

class MultiMissionTest < ActionDispatch::IntegrationTest
  setup do
    @artemis = Mission.create!(name: "Artemis Test", code: "ART-#{SecureRandom.hex(4)}")
    @mars = Mission.create!(name: "Mars Test", code: "MARS-#{SecureRandom.hex(4)}")

    @ana = Astronaut.create!(name: "Ana Test", mission: @artemis)
    @carlos = Astronaut.create!(name: "Carlos Test", mission: @artemis)
    @yuki = Astronaut.create!(name: "Yuki Test", mission: @mars)

    @ana.health_readings.create!(indicator_type: "blood_pressure_systolic", value: 150)
    @yuki.health_readings.create!(indicator_type: "blood_pressure_systolic", value: 115)
  end

  test "health_status devuelve el astronauta seleccionado" do
    get api_health_status_path, params: { mission_id: @artemis.id, astronaut_id: @ana.id }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @ana.id, body.dig("astronaut", "id")
    assert_equal "red", body["overall_status"]
  end

  test "cambiar de astronauta cambia el estado y las gráficas" do
    get api_health_status_path, params: { mission_id: @mars.id, astronaut_id: @yuki.id }
    body = JSON.parse(response.body)
    assert_equal @yuki.id, body.dig("astronaut", "id")
    assert_equal "green", body["overall_status"]

    get chart_data_api_health_readings_path, params: { astronaut_id: @yuki.id }
    datasets = JSON.parse(response.body)["datasets"]
    systolic = datasets.find { |dataset| dataset["indicatorType"] == "blood_pressure_systolic" }
    assert_equal [ 115.0 ], systolic["data"]
  end

  test "no devuelve astronautas de otra misión" do
    get api_health_status_path, params: { mission_id: @mars.id, astronaut_id: @ana.id }

    body = JSON.parse(response.body)
    assert_equal @yuki.id, body.dig("astronaut", "id")
  end

  test "crear lectura la asigna al astronauta solicitado" do
    assert_difference -> { @yuki.health_readings.count }, 1 do
      post health_readings_path,
           params: { astronaut_id: @yuki.id, health_reading: { indicator_type: "heart_rate", value: 70, unit: "bpm" } },
           as: :json
    end

    assert_response :created
    assert_equal 70.0, @yuki.health_readings.recent_first.first.value
  end
end
