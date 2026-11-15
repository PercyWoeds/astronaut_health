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
    @comm_delay_text = @astronaut ? CommDelay.text_for(@astronaut) : nil
    @comm_delays = CommDelay.environments
    @critical_alert = @astronaut ? Alert.open_for_astronaut(@astronaut).action.first : nil

    # Rule-Based Flight Surgeon + clima espacial (DONKI). Una sola llamada HTTP por render.
    @space_weather_events = @astronaut ? SpaceWeatherService.recent_solar_particles : []
    @space_weather_checked_at = Time.current
    @space_weather_error = SpaceWeatherService.last_error
    @rule_based_flight_surgeon = @astronaut ? RuleBasedFlightSurgeon.new(@astronaut, space_weather: @space_weather_events) : nil
    @rule_based_recommendations = @rule_based_flight_surgeon ? @rule_based_flight_surgeon.generate_report : []
    @health_score = @rule_based_flight_surgeon ? @rule_based_flight_surgeon.calculate_health_score : 100
    # Mientras haya una zona que requiera evaluación médica, el score se limita
    # para no mostrar un número "aceptable" (p. ej. 70) junto a ese estado.
    @health_score_capped = @snapshot&.dig(:overall_status) == "red" && @health_score > 69
    @health_score = 69 if @health_score_capped
    @rule_based_critical = @rule_based_flight_surgeon ? @rule_based_flight_surgeon.critical? : false
    @health_score_discounts = health_score_discounts(@rule_based_flight_surgeon)

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

  # Desglose de los descuentos aplicados al Crew Health Score (para el botón "Why?").
  def health_score_discounts(surgeon)
    return [] unless surgeon

    discounts = []
    sleep_average = surgeon.sleep_average
    mood_average = surgeon.mood_average
    systolic_value = surgeon.systolic_value
    diastolic_value = surgeon.diastolic_value
    glucose_value = surgeon.glucose_value

    if sleep_average && sleep_average < RuleBasedFlightSurgeon::SLEEP_THRESHOLD
      discounts << { label: "Sleep below #{RuleBasedFlightSurgeon::SLEEP_THRESHOLD.to_i} h",
                     detail: "#{sleep_average.round(1)} h average", points: 20 }
    end

    if mood_average && mood_average < RuleBasedFlightSurgeon::MOOD_THRESHOLD
      discounts << { label: "Mood below #{RuleBasedFlightSurgeon::MOOD_THRESHOLD.to_i}/10",
                     detail: "#{mood_average.round(1)}/10 average", points: 20 }
    end

    if systolic_value && systolic_value > RuleBasedFlightSurgeon::SYSTOLIC_THRESHOLD
      discounts << { label: "Systolic BP above #{RuleBasedFlightSurgeon::SYSTOLIC_THRESHOLD} mmHg",
                     detail: "#{systolic_value.round} mmHg", points: 30 }
    end

    if surgeon.diastolic_critical?
      discounts << { label: "Diastolic BP critical",
                     detail: "#{diastolic_value.round} mmHg", points: 30 }
    end

    if surgeon.glucose_critical?
      discounts << { label: "Glucose critical",
                     detail: "#{glucose_value.round} mg/dL", points: 30 }
    end

    if Array(@space_weather_events).any?
      discounts << { label: "DONKI solar alert",
                     detail: "#{Array(@space_weather_events).size} event(s)", points: 20 }
    end

    discounts
  end
end
