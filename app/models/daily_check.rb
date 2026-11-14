# Chequeo diario agregado de los riesgos fisiológicos NASA HRP / CSA.
# Se mantiene separado de HealthReading (modelo EAV de un indicador por fila)
# para no contaminar la serie temporal con columnas que solo aplican una vez al día.
class DailyCheck < ApplicationRecord
  belongs_to :astronaut

  NUMERIC_FIELDS = %w[bone_density_loss_percent co2_level stress_level calories_intake].freeze
  BOOLEAN_FIELDS = %w[vision_blurred dizziness_reported skin_rash].freeze
  FIELDS = (NUMERIC_FIELDS + BOOLEAN_FIELDS).freeze

  validates :checked_on, presence: true, uniqueness: { scope: :astronaut_id }
  validates :bone_density_loss_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :co2_level, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :stress_level, numericality: { only_integer: true, in: 1..10 }
  validates :calories_intake, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :set_defaults

  scope :recent_first, -> { order(checked_on: :desc, id: :desc) }

  # Último chequeo de un astronauta, o nil si todavía no ha registrado ninguno.
  def self.latest_for(astronaut)
    return nil unless astronaut

    astronaut.daily_checks.recent_first.first
  end

  # Evaluación completa (campos + zonas) delegada al servicio clínico.
  def evaluation
    @evaluation ||= HealthEvaluator.daily_check_summary(self)
  end

  def zone_statuses
    evaluation[:zone_statuses]
  end

  def field_status(field)
    evaluation[:field_statuses][field.to_s]
  end

  private

  def set_defaults
    self.checked_on ||= Date.current
  end
end
