# Registro de muestras biológicas (Immune Biomarkers / Standard Measures).
class BiomarkerSamplesController < ApplicationController
  before_action :ensure_astronaut!

  def create
    @sample = @astronaut.biomarker_samples.new(biomarker_sample_params)

    if @sample.save
      redirect_to dashboard_path, notice: "Muestra registrada: #{@sample.type_label}."
    else
      redirect_to dashboard_path, alert: @sample.errors.full_messages.to_sentence
    end
  end

  private

  def ensure_astronaut!
    @astronaut = requested_astronaut
    return if @astronaut

    redirect_to root_path, alert: "No hay astronauta configurado. Ejecuta rails db:seed."
  end

  def biomarker_sample_params
    params.require(:biomarker_sample).permit(:sample_type, :collected_at, :notes)
  end

  def dashboard_path
    root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id)
  end
end
