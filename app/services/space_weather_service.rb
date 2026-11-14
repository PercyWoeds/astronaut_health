# Consulta la API pública DONKI (NASA CCMC) de eventos de partículas solares (SEP).
#
# Devuelve un Array con los eventos detectados en los últimos `days` días.
# Si la red falla, la respuesta no es 200 o el JSON es inválido, devuelve [].
# El resultado se cachea para no castigar la API en cada render del dashboard.
require "net/http"
require "json"

class SpaceWeatherService
  BASE_URL = "https://ccmc.gsfc.nasa.gov/DONKI-API/get/SEP"
  CACHE_TTL = 30.minutes
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 5

  class << self
    # Seam para tests o entornos sin red: si se define, se usa en vez de HTTP.
    attr_writer :provider

    # Atajo de clase usado por el DashboardController y el AI Flight Surgeon.
    def recent_solar_particles(days: 7, now: Time.current)
      return Array(@provider.call) if @provider

      new(days: days, now: now).recent_solar_particles
    end

    def reset_provider!
      @provider = nil
    end
  end

  def initialize(days: 7, now: Time.current)
    @days = days
    @now = now
  end

  def recent_solar_particles
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_events }
  rescue StandardError => e
    # Cualquier fallo de red/parseo degrada a "sin eventos" para no romper el dashboard.
    Rails.logger.warn("[SpaceWeatherService] #{e.class}: #{e.message}")
    []
  end

  private

  attr_reader :days, :now

  def fetch_events
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(startDate: start_date, endDate: end_date)

    response = Net::HTTP.start(
      uri.host, uri.port,
      use_ssl: true,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT
    ) do |http|
      http.get(uri.request_uri, { "Accept" => "application/json" })
    end

    return [] unless response.is_a?(Net::HTTPSuccess)

    parse_events(response.body)
  end

  def parse_events(body)
    parsed = JSON.parse(body)
    parsed.is_a?(Array) ? parsed : []
  end

  def start_date
    (now.to_date - days.days).iso8601
  end

  def end_date
    now.to_date.iso8601
  end

  def cache_key
    "space_weather/donki_sep/#{start_date}/#{end_date}"
  end
end
