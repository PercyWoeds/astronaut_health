module Api
  class HealthReadingsController < ApplicationController
    # Datos crudos para integraciones o depuración.
    def index
      astronaut = requested_astronaut
      return render json: { error: "Astronauta no encontrado" }, status: :not_found unless astronaut

      readings = astronaut.health_readings.recent_first.limit(200)
      render json: readings.map { |reading|
        {
          id: reading.id,
          indicator_type: reading.indicator_type,
          label: reading.indicator_label,
          value: reading.value,
          unit: reading.unit,
          status: reading.status,
          measured_at: reading.measured_at.iso8601
        }
      }
    end

    # Formato listo para Chart.js: un dataset por indicador con sus últimos 7 valores.
    def chart_data
      astronaut = requested_astronaut
      return render json: { error: "Astronauta no encontrado" }, status: :not_found unless astronaut

      render json: HealthReading.chart_payload_for(astronaut)
    end
  end
end
