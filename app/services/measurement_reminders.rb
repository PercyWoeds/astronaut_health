# Devuelve los indicadores pendientes de medición para el día indicado,
# comparando la última lectura con la frecuencia configurada en Indicator.
class MeasurementReminders
  def self.call(astronaut, day: Date.current)
    return [] unless astronaut

    day = day.to_date
    HealthReading::INDICATOR_TYPES.select do |indicator_type|
      frequency = frequency_for(indicator_type)
      due?(astronaut, indicator_type, day, frequency)
    end
  end

  def self.frequency_for(indicator_type)
    Indicator.find_by(key: indicator_type)&.frequency_days || 1
  end

  def self.due?(astronaut, indicator_type, day, frequency)
    return false if frequency.to_i <= 0

    readings = astronaut.health_readings.for_indicator(indicator_type)
    return false if readings.on_day(day).exists?

    last = readings.where("measured_at < ?", day.beginning_of_day)
                   .order(measured_at: :desc)
                   .first
    return true if last.nil?

    (day - last.measured_at.to_date).to_i >= frequency
  end

  private_class_method :frequency_for, :due?
end
