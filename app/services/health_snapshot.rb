# Construye el estado actual de salud del astronauta listo para serializar.
# Se usa tanto en el dashboard HTML como en /api/health_status, evitando
# duplicar la lógica de agregación de zonas y recomendaciones.
class HealthSnapshot
  attr_reader :astronaut

  def initialize(astronaut)
    @astronaut = astronaut
  end

  def as_json
    {
      astronaut: astronaut_payload,
      overall_status: overall_status,
      zones: zones_payload,
      generated_at: Time.current.iso8601
    }
  end

  def overall_status
    read = astronaut.health_readings.recent_first.to_a
    Array(read).filter_map(&:status).then do |statuses|
      %w[red yellow green].find { |candidate| statuses.include?(candidate) } || "green"
    end
  end

  private

  def readings_by_type
    @readings_by_type ||= astronaut.latest_readings
  end

  def astronaut_payload
    {
      id: astronaut.id,
      name: astronaut.name,
      mission: astronaut.mission&.name,
      mission_code: astronaut.mission&.code,
      total_points: astronaut.total_points,
      achievements: astronaut.achievements.order(:name).map do |achievement|
        { id: achievement.id, name: achievement.name, description: achievement.description, points: achievement.points }
      end
    }
  end

  def zones_payload
    BodyZone.order(:id).map do |zone|
      {
        name: zone.name,
        description: zone.description,
        status: zone.status_for(readings_by_type),
        indicators: Array(zone.related_indicators).filter_map do |type|
          reading = readings_by_type[type]
          next unless reading

          {
            type: reading.indicator_type,
            label: reading.indicator_label,
            value: reading.value,
            unit: reading.unit,
            status: reading.status,
            measured_at: reading.measured_at.iso8601,
            recommendation: RecommendationEngine.for(reading)
          }
        end
      }
    end
  end
end
