class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  helper_method :current_mission, :current_astronaut

  private

  # MVP sin autenticación: la misión y el astronauta se eligen por query param
  # (?mission_id=...&astronaut_id=...). Si no hay selección, se usa el primero.
  # Para multiusuario real, reemplazar por current_user.mission / current_user.astronaut.
  def current_mission
    @current_mission ||= Mission.find_by(id: params[:mission_id]) || Mission.order(:created_at).first
  end

  # Resuelve el astronauta solicitado, siempre dentro de la misión seleccionada.
  # Si el astronauta no existe en esa misión, devuelve el primero de la misión.
  def requested_astronaut
    @requested_astronaut ||= begin
      mission = current_mission
      return nil unless mission

      if params[:astronaut_id].present?
        # Con mission_id explícito se valida pertenencia; sin él se permite
        # consultar un astronauta por id (integraciones/API directa).
        if params[:mission_id].present?
          mission.astronauts.find_by(id: params[:astronaut_id]) || mission.astronauts.order(:name).first
        else
          Astronaut.find_by(id: params[:astronaut_id]) || mission.astronauts.order(:name).first
        end
      else
        mission.astronauts.order(:name).first
      end
    end
  end

  def current_astronaut
    requested_astronaut
  end
end
