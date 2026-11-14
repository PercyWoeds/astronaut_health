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

    @current_day = Date.current
    @pending_measurements = @astronaut ? MeasurementReminders.call(@astronaut, day: @current_day) : []
    @comm_delay_text = @astronaut ? CommDelay.call(@astronaut) : nil
    @critical_alert = @astronaut ? Alert.open_for_astronaut(@astronaut).action.first : nil

    # AI Flight Surgeon + clima espacial (DONKI). Una sola llamada HTTP por render.
    @space_weather_events = @astronaut ? SpaceWeatherService.recent_solar_particles : []
    @ai_flight_surgeon = @astronaut ? AiFlightSurgeon.new(@astronaut, space_weather: @space_weather_events) : nil
    @ai_recommendations = @ai_flight_surgeon ? @ai_flight_surgeon.generate_report : []
    @health_score = @ai_flight_surgeon ? @ai_flight_surgeon.calculate_health_score : 100
    @ai_critical = @ai_flight_surgeon ? @ai_flight_surgeon.critical? : false

    # Chequeo diario (valores de hoy o del último registro como referencia).
    @daily_check = if @astronaut
      @astronaut.daily_checks.find_by(checked_on: Date.current) || DailyCheck.latest_for(@astronaut) || @astronaut.daily_checks.new
    else
      DailyCheck.new
    end
    @research_assessment = if @astronaut
      @astronaut.research_assessments.find_by(assessed_on: Date.current) ||
        ResearchAssessment.latest_for(@astronaut) ||
        @astronaut.research_assessments.new
    else
      ResearchAssessment.new
    end
    @biomarker_samples = @astronaut&.biomarker_samples&.recent_first&.limit(5) || BiomarkerSample.none
    @journal_entries = @astronaut&.journal_entries&.recent_first&.limit(5) || JournalEntry.none
    @last_pre_eva_check = @astronaut&.pre_eva_checks&.recent_first&.first
    @symptom_check = if @astronaut
      @astronaut.symptom_checks.find_by(checked_on: Date.current) ||
        SymptomCheck.latest_for(@astronaut) ||
        @astronaut.symptom_checks.new
    else
      SymptomCheck.new
    end
  end

  private

  def selected_astronaut
    return unless params[:astronaut_id].present?

    @astronauts.find_by(id: params[:astronaut_id])
  end
end
