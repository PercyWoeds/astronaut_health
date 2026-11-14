# Evaluación diaria de los estudios de investigación de la NASA:
#   - Immune Biomarkers / Standard Measures (saliva seca, virus latentes).
#   - CIPHER (calcio, telómeros, cognición espacial, vestibular, egress).
#   - SANS / B-Complex (visión, OCT, suplemento).
#   - ARCHeR (actigrafía y encuesta de rendimiento cognitivo).
#
# Se mantiene separada de DailyCheck para no mezclar los riesgos operativos
# del HRP con los biomarcadores de los protocolos de investigación.
class ResearchAssessment < ApplicationRecord
  belongs_to :astronaut

  OCT_RESULTS = %w[normal borderline abnormal].freeze

  validates :assessed_on, presence: true, uniqueness: { scope: :astronaut_id }
  validates :oct_scan_result, inclusion: { in: OCT_RESULTS }
  validates :calcium_isotopes_level, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }, allow_nil: true
  validates :telomere_length, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }, allow_nil: true
  validates :spatial_cognition_score, numericality: { only_integer: true, in: 1..100 }, allow_nil: true
  validates :cognitive_performance_survey_score, numericality: { only_integer: true, in: 0..100 }, allow_nil: true

  before_validation :set_defaults

  scope :recent_first, -> { order(assessed_on: :desc, id: :desc) }

  def self.latest_for(astronaut)
    return nil unless astronaut

    astronaut.research_assessments.recent_first.first
  end

  # El protocolo SANS exige una prueba visual al menos cada 7 días.
  # Si nunca se ha hecho, se cuenta desde la primera evaluación registrada.
  def self.vision_test_overdue?(astronaut, on: Date.current)
    return false unless astronaut

    last_true = astronaut.research_assessments.where(vision_test_performed: true).maximum(:assessed_on)
    earliest = astronaut.research_assessments.minimum(:assessed_on)
    reference = (last_true || earliest)&.to_date
    return false unless reference

    (on.to_date - reference) > 7
  end

  def evaluation(pre_eva_check: nil)
    HealthEvaluator.research_summary(self, pre_eva_check: pre_eva_check)
  end

  private

  def set_defaults
    self.assessed_on ||= Date.current
    self.oct_scan_result = "normal" if oct_scan_result.blank?
  end
end
