class SymptomReport < ApplicationRecord
  belongs_to :astronaut

  validates :astronaut_id, uniqueness: { scope: :created_at }

  scope :recent_first, -> { order(created_at: :desc) }

  def any_symptom?
    rash? || vision_change? || dizziness?
  end

  def self.latest_for(astronaut)
    return nil unless astronaut
    astronaut.symptom_reports.recent_first.first
  end
end
