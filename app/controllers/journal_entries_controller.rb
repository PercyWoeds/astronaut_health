# Diario de a bordo: contramedida del riesgo psicosocial de aislamiento.
class JournalEntriesController < ApplicationController
  before_action :ensure_astronaut!

  def create
    @entry = @astronaut.journal_entries.new(journal_entry_params)

    if @entry.save
      redirect_to dashboard_path, notice: "Journal entry saved. Recording emotions helps mitigate isolation."
    else
      redirect_to dashboard_path, alert: @entry.errors.full_messages.to_sentence
    end
  end

  private

  def ensure_astronaut!
    @astronaut = requested_astronaut
    return if @astronaut

    redirect_to root_path, alert: "No astronaut configured. Run rails db:seed."
  end

  def journal_entry_params
    params.require(:journal_entry).permit(:content)
  end

  def dashboard_path
    root_path(mission_id: @astronaut.mission_id, astronaut_id: @astronaut.id)
  end
end
