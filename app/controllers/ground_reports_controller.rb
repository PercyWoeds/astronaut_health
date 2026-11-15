class GroundReportsController < ApplicationController
  before_action :ensure_astronaut!

  def create
    alert = Alert.open_for_astronaut(@astronaut).action.first

    unless alert
      indicator = worst_indicator
      if indicator.nil?
        return redirect_to root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id),
                           alert: "Indicator catalog is empty. Run rails db:seed."
      end

      alert = @astronaut.alerts.create!(indicator: indicator, level: "action", basis: "absolute", status: "open")
    end

    report = GroundReport.create_for_alert(alert, summary: params[:summary])

    redirect_to root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id),
                notice: "Report sent to Earth. Estimated reply at #{report.earliest_reply_at.to_time.strftime('%H:%M')}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id),
                alert: e.record.errors.full_messages.to_sentence
  end

  private

  def ensure_astronaut!
    @astronaut = requested_astronaut
    return if @astronaut

    redirect_to root_path, alert: "No astronaut configured. Run rails db:seed."
  end

  def worst_indicator
    worst_reading = @astronaut.latest_readings.values.min_by do |reading|
      { "red" => 0, "yellow" => 1, "green" => 2 }.fetch(reading.status, 3)
    end

    Indicator.find_by(key: worst_reading&.indicator_type) ||
      Indicator.find_by(key: "blood_pressure_systolic") ||
      Indicator.first
  end
end
