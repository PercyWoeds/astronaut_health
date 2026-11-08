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
      awarded = GamificationService.new(@astronaut).call
      status = HealthEvaluator.new(@reading).status

      respond_to do |format|
        format.json do
          render json: {
            reading: reading_payload(@reading),
            recommendation: RecommendationEngine.for(@reading),
            status: status,
            awarded_achievements: awarded.map do |achievement|
              { name: achievement.name, description: achievement.description, points: achievement.points }
            end,
            total_points: @astronaut.total_points
          }, status: :created
        end

        format.html do
          redirect_to root_path(astronaut_id: @astronaut.id), notice: "Medición registrada (#{@reading.indicator_label}: #{@reading.value} #{@reading.unit})."
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

  private

  def ensure_astronaut!
    return if target_astronaut

    respond_to do |format|
      format.json { render json: { error: "No hay astronauta configurado. Ejecuta rails db:seed." }, status: :not_found }
      format.html { redirect_to root_path, alert: "No hay astronauta configurado. Ejecuta rails db:seed." }
    end
  end

  def target_astronaut
    @target_astronaut ||= requested_astronaut
  end

  def reading_params
    params.require(:health_reading).permit(:indicator_type, :value, :unit, :measured_at)
  end

  def reading_payload(reading)
    {
      id: reading.id,
      indicator_type: reading.indicator_type,
      label: reading.indicator_label,
      value: reading.value,
      unit: reading.unit,
      status: reading.status,
      measured_at: reading.measured_at.iso8601,
      recommendation: RecommendationEngine.for(reading)
    }
  end
end
