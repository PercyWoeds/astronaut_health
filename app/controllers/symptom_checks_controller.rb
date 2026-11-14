# Chequeo rápido de síntomas: erupción, visión y mareo.
# Es idempotente por día para no duplicar el parte clínico.
class SymptomChecksController < ApplicationController
  before_action :ensure_astronaut!

  def create
    @check = @astronaut.symptom_checks.find_or_initialize_by(checked_on: Date.current)

    if @check.update(symptom_check_params)
      if @check.any_symptom?
        redirect_to dashboard_path, alert: "Síntomas registrados. Revisa las alertas de las zonas afectadas."
      else
        redirect_to dashboard_path, notice: "Chequeo de síntomas guardado: sin novedades."
      end
    else
      redirect_to dashboard_path, alert: @check.errors.full_messages.to_sentence
    end
  end

  private

  def ensure_astronaut!
    @astronaut = requested_astronaut
    return if @astronaut

    redirect_to root_path, alert: "No hay astronauta configurado. Ejecuta rails db:seed."
  end

  def symptom_check_params
    params.require(:symptom_check).permit(:rash_or_hives, :vision_changes, :dizziness_nausea)
  end

  def dashboard_path
    root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id)
  end
end
