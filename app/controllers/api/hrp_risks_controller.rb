module Api
  # Riesgos de misión del NASA HRP para el panel de telemetría.
  # Se consume desde Stimulus para refrescar las barras cuando llega
  # una medición nueva sin recargar el dashboard.
  class HrpRisksController < ApplicationController
    def show
      astronaut = requested_astronaut
      return render json: { error: "Astronauta no encontrado" }, status: :not_found unless astronaut

      render json: { risks: HrpRiskPanel.new(astronaut).as_json }
    end
  end
end
