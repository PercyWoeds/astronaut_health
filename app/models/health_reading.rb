# Lectura puntual de un indicador de salud del astronauta.
# El status (green/yellow/red) se calcula automáticamente con HealthEvaluator
# antes de validar, de modo que cualquier alta (web, API o consola) queda evaluada.
class HealthReading < ApplicationRecord
  belongs_to :astronaut

  # Catálogo único de indicadores soportados por la herramienta.
  # label: nombre legible | unit: unidad médica canónica | range: rango heredado
  # (se mantiene por compatibilidad; la validación usa PLAUSIBILITY_RANGES).
  INDICATORS = {
    "blood_pressure_systolic"  => { label: "Systolic blood pressure", unit: "mmHg", range: 50..260 },
    "blood_pressure_diastolic" => { label: "Diastolic blood pressure", unit: "mmHg", range: 30..160 },
    "heart_rate"               => { label: "Heart rate", unit: "bpm", range: 25..220 },
    "blood_glucose"            => { label: "Blood glucose", unit: "mg/dL", range: 20..600 },
    "body_temperature"         => { label: "Body temperature", unit: "°C", range: 30.0..43.0 },
    "sleep_hours"              => { label: "Sleep hours", unit: "h", range: 0.0..24.0 },
    "mood_score"               => { label: "Mood", unit: "1-10", range: 1.0..10.0 },
    "reaction_time"            => { label: "Reaction time", unit: "ms", range: 100.0..2_000.0 },
    "meals_completed_percent"  => { label: "Meals completed %", unit: "%", range: 0.0..100.0 },
    "social_contact_minutes"   => { label: "Social contact", unit: "min", range: 0.0..1_440.0 }
  }.freeze

  INDICATOR_TYPES = INDICATORS.keys.freeze
  STATUSES = %w[green yellow red].freeze

  # Plausibility limits defined by the Quipu Space team (not a NASA source).
  # They reject capture errors (for example, 370 °C) while still allowing
  # extreme but physiologically possible values so the app can alert on them.
  PLAUSIBILITY_RANGES = {
    "blood_pressure_systolic"  => 30.0..300.0,
    "blood_pressure_diastolic" => 20.0..200.0,
    "heart_rate"               => 20.0..300.0,
    "blood_glucose"            => 10.0..1_000.0,
    "body_temperature"         => 25.0..45.0,
    "sleep_hours"              => 0.0..24.0,
    "mood_score"               => 1.0..10.0,
    "reaction_time"            => 50.0..10_000.0,
    "meals_completed_percent"  => 0.0..100.0,
    "social_contact_minutes"   => 0.0..1_440.0
  }.freeze

  # Extreme-but-possible values that require explicit confirmation.
  # These limits are also defined by the Quipu Space team, not by NASA.
  CONFIRMATION_RANGES = {
    "blood_pressure_systolic"  => { low: 70.0, high: 200.0 },
    "blood_pressure_diastolic" => { low: 40.0, high: 130.0 },
    "heart_rate"               => { low: 40.0, high: 180.0 },
    "blood_glucose"            => { low: 54.0, high: 400.0 },
    "body_temperature"         => { low: 35.0, high: 40.0 },
    "sleep_hours"              => { high: 12.0 },
    "reaction_time"            => { high: 2_000.0 }
  }.freeze

  # Units offered by the form for each indicator. The first unit is canonical.
  UNIT_OPTIONS = {
    "blood_pressure_systolic"  => %w[mmHg kPa],
    "blood_pressure_diastolic" => %w[mmHg kPa],
    "heart_rate"               => %w[bpm],
    "blood_glucose"            => %w[mg/dL mmol/L],
    "body_temperature"         => %w[°C °F],
    "sleep_hours"              => %w[h],
    "mood_score"               => %w[1-10],
    "reaction_time"            => %w[ms],
    "meals_completed_percent"  => %w[%],
    "social_contact_minutes"   => %w[min]
  }.freeze

  UNIT_CHOICES = UNIT_OPTIONS.values.flatten.uniq.freeze

  # Factor to convert a value from the selected unit to the canonical unit.
  # Fahrenheit is handled explicitly because it is an offset scale.
  UNIT_CONVERSION_FACTORS = {
    "blood_pressure_systolic"  => { "mmHg" => 1.0, "kPa" => 7.50062 },
    "blood_pressure_diastolic" => { "mmHg" => 1.0, "kPa" => 7.50062 },
    "heart_rate"               => { "bpm" => 1.0 },
    "blood_glucose"            => { "mg/dL" => 1.0, "mmol/L" => 18.0182 },
    "body_temperature"         => { "°C" => 1.0, "°F" => 1.0 },
    "sleep_hours"              => { "h" => 1.0 },
    "mood_score"               => { "1-10" => 1.0 },
    "reaction_time"            => { "ms" => 1.0 },
    "meals_completed_percent"  => { "%" => 1.0 },
    "social_contact_minutes"   => { "min" => 1.0 }
  }.freeze

  # Indicadores obligatorios para considerar completo el chequeo diario.
  # Las métricas de estudios (reacción, comidas, contacto social) son opcionales.
  DAILY_CHECKUP_INDICATORS = (INDICATOR_TYPES - %w[reaction_time meals_completed_percent social_contact_minutes]).freeze

  validates :indicator_type, inclusion: { in: INDICATOR_TYPES }
  validates :value, numericality: true
  validates :status, inclusion: { in: STATUSES }
  validates :reaction_time_ms, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :meals_completed_percent, numericality: { only_integer: true, in: 0..100 }, allow_nil: true
  validates :social_contact_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :value_within_plausible_range
  validate :unit_compatible_with_indicator
  validate :extreme_value_requires_confirmation
  validate :diastolic_less_than_systolic
  validate :measured_at_not_in_future

  before_validation :set_defaults
  before_validation :normalize_value_to_canonical_unit
  before_validation :evaluate_status

  scope :chronological, -> { order(measured_at: :asc, id: :asc) }
  scope :recent_first, -> { order(measured_at: :desc, id: :desc) }
  scope :for_indicator, ->(type) { where(indicator_type: type) }
  scope :on_day, ->(date) { where(measured_at: date.all_day) }
  scope :last_seven_for, ->(type) { for_indicator(type).recent_first.limit(7) }
  scope :baseline, -> { where(is_baseline: true) }

  # Lectura pre-vuelo de referencia para este indicador. Se usa la baseline más
  # reciente registrada antes (o al mismo tiempo) que la lectura actual.
  def baseline_reference
    return nil if is_baseline? || astronaut_id.blank? || measured_at.blank?

    @baseline_reference ||= self.class
      .baseline
      .where(astronaut_id: astronaut_id, indicator_type: indicator_type)
      .where("measured_at <= ?", measured_at)
      .order(measured_at: :desc, id: :desc)
      .first
  end

  def indicator_label
    INDICATORS.dig(indicator_type, :label) || indicator_type
  end

  # Nota legible cuando la lectura se marca por desviarse de la baseline
  # pre-vuelo, por ejemplo "baseline 62 bpm, +23 %".
  def baseline_note
    baseline = baseline_reference
    return nil unless baseline

    percent = HealthEvaluator.new(self).baseline_deviation_percent
    return nil unless percent.present? && percent > HealthEvaluator::BASELINE_DEVIATION_PERCENT

    base_value = baseline.value.to_f
    base_label = base_value % 1 == 0 ? base_value.to_i.to_s : format("%.1f", base_value)
    delta_percent = ((value.to_f - base_value) / base_value.abs) * 100
    sign = delta_percent.positive? ? "+" : ""
    "baseline #{base_label} #{unit}, #{sign}#{delta_percent.round} %"
  end

  # True when the value is extreme but still physiologically possible.
  def extreme_value?
    return false if value.blank?

    range = self.class.confirmation_range_for(indicator_type)
    return false unless range

    (range[:low] && value.to_f < range[:low]) || (range[:high] && value.to_f > range[:high])
  end

  def extreme_direction
    return nil unless extreme_value?

    range = self.class.confirmation_range_for(indicator_type)
    range[:low] && value.to_f < range[:low] ? "low" : "high"
  end

  # A very similar reading for the same indicator in the 5 minutes before this
  # one. It is returned as a warning; it never blocks the save.
  def duplicate_of_recent_reading
    return nil if astronaut_id.blank? || indicator_type.blank? || measured_at.blank? || value.blank?

    self.class
      .where(astronaut_id: astronaut_id, indicator_type: indicator_type)
      .where.not(id: id)
      .where(measured_at: (measured_at - 5.minutes)..measured_at)
      .where("ABS(value - ?) < ?", value.to_f, 0.01)
      .recent_first
      .first
  end

  def canonical_unit
    INDICATORS.dig(indicator_type, :unit)
  end

  def self.plausibility_range_for(indicator_type)
    PLAUSIBILITY_RANGES[indicator_type]
  end

  def self.confirmation_range_for(indicator_type)
    CONFIRMATION_RANGES[indicator_type]
  end

  # Range considered normal by HealthEvaluator (green zone), used as help text.
  def self.expected_range_for(indicator_type)
    thresholds = HealthEvaluator::THRESHOLDS[indicator_type]
    plausibility = plausibility_range_for(indicator_type)
    return nil unless thresholds && plausibility

    low = thresholds[:yellow_low] || thresholds[:red_low] || plausibility.min
    high = thresholds[:yellow_high] || thresholds[:red_high] || plausibility.max
    low..high
  end

  def self.unit_options_for(indicator_type)
    UNIT_OPTIONS.fetch(indicator_type, [ INDICATORS.dig(indicator_type, :unit) ].compact)
  end

  def self.status_badge_class(status)
    {
      "green" => "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
      "yellow" => "bg-amber-500/15 text-amber-300 border-amber-500/40",
      "red" => "bg-rose-500/15 text-rose-300 border-rose-500/40"
    }.fetch(status, "bg-slate-500/15 text-slate-300 border-slate-500/40")
  end

  # Hash listo para el endpoint de Chart.js:
  # { labels: [...], datasets: [{ label:, data:, ... }] }
  def self.chart_payload_for(astronaut)
    datasets = INDICATOR_TYPES.filter_map do |type|
      readings = astronaut.health_readings.last_seven_for(type).to_a.reverse
      next if readings.empty?

      {
        label: INDICATORS.dig(type, :label),
        indicatorType: type,
        unit: INDICATORS.dig(type, :unit),
        data: readings.map { |r| r.value },
        labels: readings.map { |r| r.measured_at.strftime("%d/%m %H:%M") },
        statuses: readings.map(&:status)
      }
    end

    { datasets: datasets }
  end

  private

  def set_defaults
    self.measured_at ||= Time.current
    self.unit = unit.presence || canonical_unit
  end

  # Converts compatible units (mmol/L, °F, kPa) to the canonical unit so the
  # evaluator and the plausibility limits always work with the same scale.
  def normalize_value_to_canonical_unit
    return if indicator_type.blank? || value.blank? || unit.blank?
    return if unit == canonical_unit

    return unless UNIT_CONVERSION_FACTORS.dig(indicator_type, unit)

    self.value = converted_value_to_canonical(value.to_f, unit)
    self.unit = canonical_unit
  end

  def converted_value_to_canonical(raw_value, from_unit)
    return (raw_value - 32.0) * 5.0 / 9.0 if indicator_type == "body_temperature" && from_unit == "°F"

    raw_value * UNIT_CONVERSION_FACTORS.dig(indicator_type, from_unit)
  end

  # Delega el cálculo clínico al servicio especializado.
  def evaluate_status
    return if indicator_type.blank? || value.blank?

    self.status = HealthEvaluator.new(self).status
  end

  # Legacy entry point kept for compatibility. The team-defined ranges live in
  # plausibility_range so both validations share a single source of truth.
  def value_within_plausible_range
    plausibility_range
  end

  def plausibility_range
    return if indicator_type.blank? || value.blank?
    return if errors[:value].any?

    range = self.class.plausibility_range_for(indicator_type)
    return unless range

    unless range.cover?(value.to_f)
      errors.add(:value, invalid_plausibility_message(range))
      return
    end

    return unless indicator_type == "mood_score" && value.to_f != value.to_i

    errors.add(:value, "must be a whole number between #{range.min.to_i} and #{range.max.to_i}.")
  end

  def invalid_plausibility_message(range)
    "must be between #{format_limit(range.min)} and #{format_limit(range.max)} #{canonical_unit} " \
      "(#{indicator_label}). Please check the value and unit."
  end

  def format_limit(limit)
    limit.to_f == limit.to_i ? limit.to_i.to_s : format("%.1f", limit)
  end

  def unit_compatible_with_indicator
    return if indicator_type.blank? || unit.blank?
    return if self.class.unit_options_for(indicator_type).include?(unit)

    errors.add(:unit, "is not compatible with #{indicator_label}. " \
      "Use #{self.class.unit_options_for(indicator_type).join(' or ')}.")
  end

  def extreme_value_requires_confirmation
    return if confirmed? || !extreme_value?
    return if errors[:value].any?

    errors.add(:base, "This value is very #{extreme_direction}. Please confirm it before saving.")
  end

  def diastolic_less_than_systolic
    return unless indicator_type == "blood_pressure_diastolic"
    return if value.blank? || astronaut_id.blank? || errors[:value].any?

    systolic = self.class
      .for_indicator("blood_pressure_systolic")
      .where(astronaut_id: astronaut_id)
      .where("measured_at <= ?", measured_at || Time.current)
      .recent_first
      .first
    return unless systolic
    return if value.to_f < systolic.value.to_f

    errors.add(:value, "must be lower than the latest systolic pressure " \
      "(#{format_limit(systolic.value)} mmHg).")
  end

  def measured_at_not_in_future
    return if measured_at.blank? || measured_at <= Time.current

    errors.add(:measured_at, "can't be in the future. Choose the current time or an earlier one.")
  end
end
