class Indicator < ApplicationRecord
  AXES = %w[vital cognitive behavioral nutritional].freeze
  BAD_DIRECTIONS = %w[high low].freeze

  has_many :baselines, dependent: :destroy
  has_many :alerts, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :axis, inclusion: { in: AXES }
  validates :unit, presence: true
  validates :bad_direction, inclusion: { in: BAD_DIRECTIONS }
  validates :frequency_days, numericality: { only_integer: true, greater_than: 0 }

  scope :for_axis, ->(axis) { where(axis: axis) }
  scope :daily, -> { where(frequency_days: 1) }
  scope :weekly, -> { where(frequency_days: 7) }

  def self.catalog
    {
      "blood_pressure_systolic"  => { axis: "vital", unit: "mmHg", bad_direction: "high",
        abs_min: 50, abs_max: 260, yellow_min: 90, yellow_max: 130, red_min: 85, red_max: 140,
        hazards: "Riesgo cardiovascular y remodelado arterial acelerado en microgravedad.",
        source_url: "https://www.nasa.gov/hrp", frequency_days: 1 },
      "blood_pressure_diastolic" => { axis: "vital", unit: "mmHg", bad_direction: "high",
        abs_min: 30, abs_max: 160, yellow_min: 60, yellow_max: 80, red_min: 50, red_max: 90,
        hazards: "Hipertensión o bajo gasto cardíaco.", source_url: "https://www.nasa.gov/hrp",
        frequency_days: 1 },
      "heart_rate"               => { axis: "vital", unit: "bpm", bad_direction: "high",
        abs_min: 25, abs_max: 220, yellow_min: 50, yellow_max: 100, red_min: 40, red_max: 130,
        hazards: "Taquicardia persistente o bradicardia sintomática.", source_url: "https://www.nasa.gov/hrp",
        frequency_days: 1 },
      "blood_glucose"            => { axis: "vital", unit: "mg/dL", bad_direction: "high",
        abs_min: 20, abs_max: 600, yellow_min: 70, yellow_max: 180, red_min: 54, red_max: 250,
        hazards: "Hipoglucemia o hiperglucemia en vuelo.", source_url: "https://www.nasa.gov/hrp",
        frequency_days: 1 },
      "body_temperature"         => { axis: "vital", unit: "°C", bad_direction: "high",
        abs_min: 30.0, abs_max: 43.0, yellow_min: 36.0, yellow_max: 38.0, red_min: 35.0, red_max: 39.0,
        hazards: "Hipotermia o fiebre en entorno cerrado.", source_url: "https://www.nasa.gov/hrp",
        frequency_days: 1 },
      "sleep_hours"              => { axis: "behavioral", unit: "h", bad_direction: "low",
        abs_min: 0.0, abs_max: 24.0, yellow_min: 6.0, yellow_max: 10.0, red_min: 4.0, red_max: 12.0,
        hazards: "Déficit crónico de sueño y riesgo de fatiga.", source_url: "https://www.nasa.gov/hrp",
        frequency_days: 1 },
      "mood_score"               => { axis: "cognitive", unit: "1-10", bad_direction: "low",
        abs_min: 1.0, abs_max: 10.0, yellow_min: 6.0, yellow_max: 10.0, red_min: 4.0, red_max: 10.0,
        hazards: "Riesgo psicosocial por aislamiento y confinamiento.", source_url: "https://www.nasa.gov/hrp",
        frequency_days: 1 },
      "reaction_time"            => { axis: "cognitive", unit: "ms", bad_direction: "high",
        abs_min: 100.0, abs_max: 2_000.0, yellow_min: 100.0, yellow_max: 500.0, red_min: 100.0, red_max: 800.0,
        hazards: "Fatiga cognitiva en tareas de vigilancia.", source_url: "https://www.nasa.gov/cipher",
        frequency_days: 7 },
      "meals_completed_percent"  => { axis: "nutritional", unit: "%", bad_direction: "low",
        abs_min: 0.0, abs_max: 100.0, yellow_min: 50.0, yellow_max: 100.0, red_min: 25.0, red_max: 100.0,
        hazards: "Riesgo de nutrición inadecuada en microgravedad.", source_url: "https://www.nasa.gov/hrp",
        frequency_days: 1 },
      "social_contact_minutes"   => { axis: "behavioral", unit: "min", bad_direction: "low",
        abs_min: 0.0, abs_max: 1_440.0, yellow_min: 10.0, yellow_max: 1_440.0, red_min: 1.0, red_max: 1_440.0,
        hazards: "Aislamiento social y deterioro psicosocial.", source_url: "https://www.nasa.gov/archer",
        frequency_days: 1 }
    }
  end

  def self.seed_catalog!
    catalog.each do |key, attrs|
      indicator = find_or_initialize_by(key: key)
      indicator.assign_attributes(attrs)
      indicator.save!
    end
  end

  def label
    I18n.t("indicators.#{key}", default: key.humanize)
  end
end
