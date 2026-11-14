# Astronauta participante en una misión espacial.
# Es la entidad raíz: acumula lecturas de salud y logros de gamificación.
class Astronaut < ApplicationRecord
  belongs_to :mission

  DESTINATIONS = %w[iss moon mars].freeze

  has_many :health_readings, dependent: :destroy
  has_many :daily_checks, dependent: :destroy
  has_many :research_assessments, dependent: :destroy
  has_many :biomarker_samples, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :pre_eva_checks, dependent: :destroy
  has_many :symptom_checks, dependent: :destroy
  has_many :astronaut_achievements, dependent: :destroy
  has_many :achievements, through: :astronaut_achievements
  has_many :baselines, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :symptom_reports, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :mission_id }
  validates :destination, inclusion: { in: DESTINATIONS }

  # Indica si la lectura es una línea base pre-vuelo para este indicador.
  def baseline_for_indicator?(indicator_type)
    health_readings.where(astronaut: self, indicator_type: indicator_type, is_baseline: true).first
  end

  def total_points
    achievements.sum(:points)
  end

  def latest_readings
    health_readings
      .order(measured_at: :desc, id: :desc)
      .to_a
      .each_with_object({}) do |reading, memo|
        memo[reading.indicator_type] ||= reading
      end
  end
end
