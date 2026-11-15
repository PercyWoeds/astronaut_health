# One-way communication delay by mission destination.
#
# Source block:
#   - Moon: ~1.3 s one way.
#   - Mars: a few minutes to more than 20 min. Measured example: 11 min 22 s.
#   - ISS: low-latency link (simulated in this app).
#
# The value is informational: it never changes a health status or turns a zone
# into Follow-up. The Mars demo value can be overridden with the environment
# variable MARS_ONE_WAY_DELAY_MINUTES (clamped to the documented range).
class CommDelay
  MARS_DEFAULT_MINUTES = 11.38
  MARS_MIN_MINUTES = 2.0
  MARS_MAX_MINUTES = 40.0
  ISS_SECONDS = 0.5
  MOON_SECONDS = 1.3

  SOURCES = {
    "iss" => "ISS low-latency link is simulated in this app.",
    "moon" => "ESA Mars Express blog (blogs.esa.int/mex/?p=257): Moon one-way delay ~1.3 s.",
    "mars" => "NASA Mars 2020 blog (blogs.nasa.gov/mars2020/2021): measured example 11 min 22 s; " \
              "real range is a few minutes to more than 20 min."
  }.freeze

  def self.mars_seconds
    minutes = ENV.fetch("MARS_ONE_WAY_DELAY_MINUTES", MARS_DEFAULT_MINUTES.to_s).to_f
    minutes = MARS_MIN_MINUTES if minutes < MARS_MIN_MINUTES
    minutes = MARS_MAX_MINUTES if minutes > MARS_MAX_MINUTES
    minutes * 60
  end

  def self.seconds_for(astronaut)
    destination = astronaut&.destination || "iss"
    seconds_for_destination(destination)
  end

  def self.seconds_for_destination(destination)
    case destination.to_s
    when "moon" then MOON_SECONDS
    when "mars" then mars_seconds
    else ISS_SECONDS
    end
  end

  def self.text_for(astronaut)
    label_for(astronaut&.destination || "iss")
  end

  def self.label_for(destination)
    seconds = seconds_for_destination(destination)
    "Delay with Earth: #{format_delay(seconds)}"
  end

  def self.format_delay(seconds)
    if seconds < 1
      "< 1 s (simulated low-latency link)"
    elsif seconds < 60
      "≈ #{format('%.1f', seconds)} s"
    else
      minutes = seconds / 60.0
      whole = minutes.floor
      remainder = ((minutes - whole) * 60).round
      range = destination_range(minutes)
      base = if remainder.zero?
        "#{whole} min"
      else
        "#{whole} min #{remainder} s"
      end
      "#{base} (demo value; #{range})"
    end
  end

  def self.protocol_for(destination)
    seconds = seconds_for_destination(destination)
    "One-way delay: #{format_delay(seconds)}. Autonomous protocol active. " \
      "Communication delay is informational and does not change the health status."
  end

  # Data consumed by the environment selector. Keys match Astronaut::DESTINATIONS.
  def self.environments
    %w[iss moon mars].index_with do |destination|
      {
        delay: format_delay(seconds_for_destination(destination)),
        protocol: protocol_for(destination)
      }
    end
  end

  def self.round_trip_seconds_for(astronaut)
    seconds_for(astronaut) * 2
  end

  def self.destination_range(minutes)
    if minutes >= MARS_MIN_MINUTES
      "real range: a few minutes to more than 20 min"
    else
      "approximate"
    end
  end
  private_class_method :destination_range
end
