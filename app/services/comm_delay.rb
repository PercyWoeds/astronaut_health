# Calcula el retraso de comunicaciones (one-way) basado en el destino de la misión.
# Valores aproximados de la demo: la ISS está en órbita baja (near real-time),
# la Luna ~1.3 s y Marte hasta ~20 min.
class CommDelay
  # En segundos.
  DELAYS = {
    "iss" => 0.0,
    "moon" => 1.3,
    "mars" => 20 * 60
  }.freeze

  def self.call(astronaut)
    destination = astronaut.destination || "iss"
    DELAYS.fetch(destination, DELAYS["iss"])
  end

  def self.seconds_for(astronaut)
    call(astronaut)
  end

  def self.text_for(astronaut)
    seconds = call(astronaut)
    if seconds < 1
      "Delay with Earth: < 1 s (near real-time)"
    elsif seconds < 60
      "Delay with Earth: #{format('%.1f', seconds)} s"
    else
      "Delay with Earth: #{(seconds / 60.0).round} min"
    end
  end
end
