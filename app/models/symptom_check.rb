# Chequeo rápido de síntomas de los estudios NASA.
# Se mantiene fuera de HealthReading porque son tres banderas clínicas diarias,
# no una serie temporal de un único indicador.
class SymptomCheck < ApplicationRecord
  belongs_to :astronaut

  FIELDS = %w[rash_or_hives vision_changes dizziness_nausea].freeze

  validates :checked_on, presence: true, uniqueness: { scope: :astronaut_id }

  before_validation :set_defaults

  scope :recent_first, -> { order(checked_on: :desc, id: :desc) }

  def self.latest_for(astronaut)
    return nil unless astronaut

    astronaut.symptom_checks.recent_first.first
  end

  def evaluation
    @evaluation ||= HealthEvaluator.symptom_check_summary(self)
  end

  def any_symptom?
    FIELDS.any? { |field| public_send(field) }
  end

  private

  def set_defaults
    self.checked_on ||= Date.current
  end
end
