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
end
