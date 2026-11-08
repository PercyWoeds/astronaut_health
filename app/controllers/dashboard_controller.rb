# Vista principal: cuerpo 3D, resumen de estado, gráficas y gamificación.
# Soporta múltiples misiones y astronautas mediante ?mission_id y ?astronaut_id.
class DashboardController < ApplicationController
  def index
    @missions = Mission.order(:name)
    @current_mission = Mission.find_by(id: params[:mission_id]) || Mission.order(:created_at).first
    @astronauts = @current_mission ? @current_mission.astronauts.order(:name) : Astronaut.none
    @astronaut = selected_astronaut || @astronauts.first

    @snapshot = @astronaut ? HealthSnapshot.new(@astronaut).as_json : nil
    @hrp_risks = @astronaut ? HrpRiskPanel.new(@astronaut).as_json : []
    @latest_readings = @astronaut&.latest_readings || {}
    @recent_readings = @astronaut&.health_readings&.recent_first&.limit(10) || HealthReading.none
    @achievements = @astronaut&.achievements&.order(:name) || Achievement.none
    @next_achievements = Achievement.where.not(id: @achievements.select(:id)).order(:points)
    @indicator_options = HealthReading::INDICATORS
  end

  private

  def selected_astronaut
    return unless params[:astronaut_id].present?

    @astronauts.find_by(id: params[:astronaut_id])
  end
end
