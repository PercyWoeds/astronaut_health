# Checklist previo a una EVA simulada. Los tres checks deben estar marcados.
class PreEvaChecksController < ApplicationController
  before_action :ensure_astronaut!

  def create
    @check = @astronaut.pre_eva_checks.new(pre_eva_check_params)

    if @check.save
      if @check.ready?
        redirect_to dashboard_path, notice: "Pre-EVA and Egress Fitness checklist complete. Activity authorized."
      else
        redirect_to dashboard_path, alert: "Incomplete checklist: confirm O2, pressure, fatigue and Egress Fitness."
      end
    else
      redirect_to dashboard_path, alert: @check.errors.full_messages.to_sentence
    end
  end

  private

  def ensure_astronaut!
    @astronaut = requested_astronaut
    return if @astronaut

    redirect_to root_path, alert: "No astronaut configured. Run rails db:seed."
  end

  def pre_eva_check_params
    params.require(:pre_eva_check).permit(:o2_ok, :pressure_ok, :fatigue_ok, :egress_fitness_completed)
  end

  def dashboard_path
    root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id)
  end
end
