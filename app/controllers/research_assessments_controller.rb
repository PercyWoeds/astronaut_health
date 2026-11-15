# Registra la evaluación diaria de los estudios NASA:
# Immune Biomarkers, CIPHER, SANS/B-Complex y ARCHeR.
class ResearchAssessmentsController < ApplicationController
  before_action :ensure_astronaut!

  def create
    @assessment = @astronaut.research_assessments.find_or_initialize_by(assessed_on: Date.current)

    if @assessment.update(research_assessment_params)
      redirect_to dashboard_path, notice: "NASA studies saved (Immune / CIPHER / SANS / ARCHeR)."
    else
      redirect_to dashboard_path, alert: @assessment.errors.full_messages.to_sentence
    end
  end

  private

  def ensure_astronaut!
    @astronaut = requested_astronaut
    return if @astronaut

    redirect_to root_path, alert: "No astronaut configured. Run rails db:seed."
  end

  def research_assessment_params
    params.require(:research_assessment).permit(
      :saliva_sample_taken, :virus_reactivation_suspected,
      :calcium_isotopes_level, :telomere_length, :spatial_cognition_score, :vestibular_test_passed,
      :vision_test_performed, :oct_scan_result, :b_complex_supplement_taken,
      :actigraphy_device_synced, :cognitive_performance_survey_score
    )
  end

  def dashboard_path
    root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id)
  end
end
