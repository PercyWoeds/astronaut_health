# Registro de muestras biológicas (Immune Biomarkers / Standard Measures).
class BiomarkerSample < ApplicationRecord
  belongs_to :astronaut

  SAMPLE_TYPES = {
    "saliva_dry" => "Saliva seca (Artemis)",
    "blood" => "Sangre",
    "urine" => "Orina"
  }.freeze

  validates :sample_type, inclusion: { in: SAMPLE_TYPES.keys }
  validates :collected_at, presence: true
  validates :notes, length: { maximum: 1_000 }

  before_validation :set_collected_at

  scope :recent_first, -> { order(collected_at: :desc, id: :desc) }

  def type_label
    SAMPLE_TYPES.fetch(sample_type, sample_type)
  end

  private

  def set_collected_at
    self.collected_at ||= Time.current
  end
end
