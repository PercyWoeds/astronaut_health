require "test_helper"

class SpaceWeatherServiceTest < ActiveSupport::TestCase
  class NetworkFailureService < SpaceWeatherService
    private

    def fetch_events
      raise SocketError, "network down"
    end
  end

  test "devuelve [] si la red falla" do
    assert_equal [], NetworkFailureService.recent_solar_particles
  end

  test "parsea un arreglo JSON de eventos" do
    service = SpaceWeatherService.new

    assert_equal [ { "sepID" => "SEP-1" } ], service.send(:parse_events, '[{"sepID":"SEP-1"}]')
  end

  test "devuelve [] si el JSON no es un arreglo" do
    service = SpaceWeatherService.new

    assert_equal [], service.send(:parse_events, '{"error":"unexpected"}')
  end

  test "expone el ultimo error de DONKI en vez de propagarlo" do
    service = NetworkFailureService.new
    assert_equal [], service.recent_solar_particles
    assert_equal "SocketError: network down", service.last_error
  end

  test "el atajo de clase limpia el error entre consultas" do
    SpaceWeatherService.reset_provider!
    assert_nil SpaceWeatherService.last_error
  end
end
