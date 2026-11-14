# Guarda el chequeo diario de riesgos fisiológicos NASA HRP / CSA.
# Es idempotente por día: si ya existe uno para hoy, lo actualiza.
class DailyChecksController < ApplicationController
  before_action :ensure_astronaut!

  def create
    @daily_check = @astronaut.daily_checks.find_or_initialize_by(checked_on: Date.current)

    if @daily_check.update(daily_check_params)
      redirect_to dashboard_path, notice: "Chequeo diario guardado para #{@daily_check.checked_on.strftime('%d/%m/%Y')}."
    else
      redirect_to dashboard_path, alert: @daily_check.errors.full_messages.to_sentence
    end
  end

  private

  def ensure_astronaut!
    @astronaut = requested_astronaut
    return if @astronaut

    redirect_to root_path, alert: "No hay astronauta configurado. Ejecuta rails db:seed."
  end

  def daily_check_params
    params.require(:daily_check).permit(
      :bone_density_loss_percent, :co2_level, :stress_level, :calories_intake,
      :vision_blurred, :dizziness_reported, :skin_rash
    )
  end

  def dashboard_path
    root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id)
  end
end
