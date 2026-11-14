# Calcula estadísticas de línea base usando lecturas de referencia.
class BaselineCalculator
  def self.calculate(astronaut, indicator_type, days_back = 7, is_baseline: false)
    # Si no se especifican criterios, toma las primeras N lecturas que sean baseline OR las últimas N lecturas totales.
    readings = if is_baseline
      astronaut.health_readings
        .where(indicator_type: indicator_type, is_baseline: true)
        .order(measured_at: :asc, id: :asc)
        .limit(days_back)
    else
      astronaut.health_readings
        .where(indicator_type: indicator_type)
        .order(measured_at: :asc, id: :asc)
        .limit(days_back)
    end

    return nil if readings.empty?

    values = readings.map(&:value)
    mean = values.sum / values.length
    std = calculate_standard_deviation(values, mean)

    # Guarda el baseline en el nuevo modelo Baseline
    Baseline.create(
      astronaut: astronaut,
      indicator: Indicator.find_by(key: indicator_type),
      mean: mean,
      std: std,
      samples: values.length,
      source: is_baseline ? "pre-flight" : "in-flight"
    )
  end

  private

  def self.calculate_standard_deviation(values, mean)
    return 0 if values.length <= 1

    variance = values.map { |v| (v - mean)**2 }.sum / values.length
    Math.sqrt(variance)
  end
end
