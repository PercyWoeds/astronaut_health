# Detecta anomalías comparando una lectura con su línea base (Z-score) o,
# si no hay baseline, con los rangos absolutos del catálogo de Indicator.
class AnomalyDetector
  STATUSES = %w[green watch action].freeze

  def self.evaluate(reading, baseline = nil)
    level = baseline ? evaluate_with_baseline(reading, baseline) : evaluate_with_ranges(reading)
    create_alert(reading, level)
    level
  end

  def self.evaluate_with_baseline(reading, baseline)
    z = baseline.z_score(reading.value)
    return "green" if z.nil?

    if z.abs > 2
      "action"
    elsif z.abs > 1
      "watch"
    else
      "green"
    end
  end

  def self.evaluate_with_ranges(reading)
    indicator = Indicator.find_by(key: reading.indicator_type)
    return "green" unless indicator

    value = reading.value.to_f

    if indicator.bad_direction == "high"
      return "action" if indicator.red_max && value >= indicator.red_max
      return "watch" if indicator.yellow_max && value >= indicator.yellow_max
    else
      return "action" if indicator.red_min && value <= indicator.red_min
      return "watch" if indicator.yellow_min && value <= indicator.yellow_min
    end

    "green"
  end

  def self.create_alert(reading, level)
    return if level == "green"

    indicator = Indicator.find_by(key: reading.indicator_type)
    return unless indicator

    alert = Alert.find_or_initialize_by(
      astronaut: reading.astronaut,
      indicator: indicator,
      status: "open"
    )
    alert.update!(
      level: level,
      basis: reading.baseline_reference ? "baseline" : "absolute",
      note: "Reading #{reading.value} #{reading.unit}"
    )
  end

  private_class_method :evaluate_with_baseline, :evaluate_with_ranges, :create_alert
end
