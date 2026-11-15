# Captura y listado de mediciones.
# `create` responde JSON para que el formulario del dashboard actualice el
# cuerpo 3D y las gráficas sin recargar la página.
class HealthReadingsController < ApplicationController
  before_action :ensure_astronaut!

  def index
    @astronaut = target_astronaut
    @readings = @astronaut.health_readings.recent_first.limit(200)

    respond_to do |format|
      format.html
      format.json do
        render json: @readings.map { |reading| reading_payload(reading) }
      end
    end
  end

  def new
    @astronaut = target_astronaut
    @reading = @astronaut.health_readings.new(measured_at: Time.current)
    @indicator_options = HealthReading::INDICATORS
  end

  def create
    @astronaut = target_astronaut
    @reading = @astronaut.health_readings.new(reading_params)

    if @reading.save
      create_critical_alert_if_needed
      awarded = GamificationService.new(@astronaut).call
      status = HealthEvaluator.new(@reading).status
      warning = duplicate_warning

      respond_to do |format|
        format.json do
          render json: {
            reading: reading_payload(@reading),
            recommendation: RecommendationEngine.for(@reading),
            status: status,
            warning: warning,
            awarded_achievements: awarded.map do |achievement|
              { name: achievement.name, description: achievement.description, points: achievement.points }
            end,
            total_points: @astronaut.total_points
          }, status: :created
        end

        format.html do
          redirect_to root_path(astronaut_id: @astronaut.id), notice: [ "Measurement recorded (#{@reading.indicator_label}: #{@reading.value} #{@reading.unit}).", warning ].compact.join(" ")
        end
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @reading.errors.full_messages }, status: :unprocessable_entity }
        format.html do
          @indicator_options = HealthReading::INDICATORS
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @astronaut = target_astronaut
    @reading = @astronaut.health_readings.find(params[:id])
    @reading.destroy!

    respond_to do |format|
      format.html do
        redirect_to root_path(mission_id: current_mission&.id, astronaut_id: @astronaut.id),
                    notice: "Last reading undone."
      end
      format.json { head :no_content }
    end
  end

  private

  def create_critical_alert_if_needed
    return unless @reading.confirmed? && @reading.extreme_value?

    indicator = Indicator.find_by(key: @reading.indicator_type)
    return unless indicator

    alert = @astronaut.alerts.find_or_initialize_by(indicator: indicator, status: "open")
    alert.update!(
      level: "action",
      basis: "absolute",
      note: "Confirmed extreme value: #{@reading.value} #{@reading.unit}"
    )
  end

  def duplicate_warning
    return nil unless @reading.duplicate_of_recent_reading

    "Warning: a very similar reading was recorded less than 5 minutes before this one. Please verify it is not a duplicate."
  end

  def ensure_astronaut!
    return if target_astronaut

    respond_to do |format|
      format.json { render json: { error: "No astronaut configured. Run rails db:seed." }, status: :not_found }
      format.html { redirect_to root_path, alert: "No astronaut configured. Run rails db:seed." }
    end
  end

  def target_astronaut
    @target_astronaut ||= requested_astronaut
  end

  def reading_params
    params.require(:health_reading).permit(
      :indicator_type, :value, :unit, :measured_at, :is_baseline, :confirmed,
      :reaction_time_ms, :meals_completed_percent, :social_contact_minutes
    )
  end

  def reading_payload(reading)
    {
      id: reading.id,
      indicator_type: reading.indicator_type,
      label: reading.indicator_label,
      value: reading.value,
      unit: reading.unit,
      status: reading.status,
      confirmed: reading.confirmed?,
      extreme: reading.extreme_value?,
      measured_at: reading.measured_at.iso8601,
      recommendation: RecommendationEngine.for(reading)
    }
  end
end
