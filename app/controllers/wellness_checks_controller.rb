# Registra las métricas diarias de nutrición y contacto social como
# HealthReading, manteniendo una sola fila por indicador y día.
class WellnessChecksController < ApplicationController
  before_action :ensure_astronaut!

  def create
    values = wellness_params

    if values[:meals_completed_percent].blank? && values[:social_contact_minutes].blank?
      return redirect_to dashboard_path, alert: "Enter at least one meal or social contact value."
    end

    HealthReading.transaction do
      upsert_reading("meals_completed_percent", values[:meals_completed_percent], :meals_completed_percent)
      upsert_reading("social_contact_minutes", values[:social_contact_minutes], :social_contact_minutes)
    end

    redirect_to dashboard_path, notice: "Meals and social contact updated."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to dashboard_path, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def ensure_astronaut!
    @astronaut = requested_astronaut
    return if @astronaut

    redirect_to root_path, alert: "No astronaut configured. Run rails db:seed."
  end

  def wellness_params
    params.require(:wellness_check).permit(:meals_completed_percent, :social_contact_minutes)
  end

  def upsert_reading(indicator_type, value, column)
    return if value.blank?

    reading = @astronaut.health_readings
      .where(indicator_type: indicator_type, measured_at: Time.zone.now.all_day)
      .recent_first
      .first_or_initialize

    reading.assign_attributes(
      indicator_type: indicator_type,
      value: value,
      measured_at: Time.current,
      column => value
    )
    reading.save!
  end

  def dashboard_path
    root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id)
  end
end
