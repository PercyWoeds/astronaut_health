# Calcula el retraso de comunicaciones basado en el destino de la misión.
# Calcula el retraso de comunicaciones basado en el destino de la misión.
class CommDelay
  # En minutos.
  DELAYS = {
    "iss" => 20,
    "moon" => 30,
    "mars" => 60
  }.freeze

  def self.call(astronaut)
    destination = astronaut.destination || "iss"
    minutes = DELAYS.fetch(destination, DELAYS["iss"])
    minutes * 60
  end

  def self.seconds_for(astronaut)
    call(astronaut)
  end

  def self.text_for(astronaut)
    minutes = (call(astronaut) / 60.0).to_i
    "Retraso con la Tierra: #{minutes} min"
  end
end
