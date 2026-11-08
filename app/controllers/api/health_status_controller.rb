module Api
  # Estado agregado por zona corporal para que Three.js pinte los meshes.
  class HealthStatusController < ApplicationController
    def show
      astronaut = requested_astronaut
      return render json: { error: "Astronauta no encontrado" }, status: :not_found unless astronaut

      render json: HealthSnapshot.new(astronaut).as_json
    end
  end
end
