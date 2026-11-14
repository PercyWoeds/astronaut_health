# Lectura puntual de un indicador de salud del astronauta.
# El status (green/yellow/red) se calcula automáticamente con HealthEvaluator
# antes de validar, de modo que cualquier alta (web, API o consola) queda evaluada.
class HealthReading < ApplicationRecord
  belongs_to :astronaut

  # Catálogo único de indicadores soportados por la herramienta.
  # label: nombre legible | unit: unidad médica | range: rango de captura permitido.
  INDICATORS = {
    "blood_pressure_systolic"  => { label: "Presión arterial sistólica", unit: "mmHg", range: 50..260 },
    "blood_pressure_diastolic" => { label: "Presión arterial diastólica", unit: "mmHg", range: 30..160 },
    "heart_rate"               => { label: "Frecuencia cardíaca", unit: "bpm", range: 25..220 },
    "blood_glucose"            => { label: "Glucosa en sangre", unit: "mg/dL", range: 20..600 },
    "body_temperature"         => { label: "Temperatura corporal", unit: "°C", range: 30.0..43.0 },
    "sleep_hours"              => { label: "Horas de sueño", unit: "h", range: 0.0..24.0 },
    "mood_score"               => { label: "Estado de ánimo", unit: "1-10", range: 1.0..10.0 },
    "reaction_time"            => { label: "Tiempo de reacción", unit: "ms", range: 100.0..2_000.0 },
    "meals_completed_percent"  => { label: "% Comidas completadas", unit: "%", range: 0.0..100.0 },
    "social_contact_minutes"   => { label: "Contacto social", unit: "min", range: 0.0..1_440.0 }
  }.freeze

  INDICATOR_TYPES = INDICATORS.keys.freeze
  STATUSES = %w[green yellow red].freeze

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

  before_validation :set_defaults
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
    self.unit = unit.presence || INDICATORS.dig(indicator_type, :unit)
  end

  # Delega el cálculo clínico al servicio especializado.
  def evaluate_status
    return if indicator_type.blank? || value.blank?

    self.status = HealthEvaluator.new(self).status
  end

  def value_within_plausible_range
    return if indicator_type.blank? || value.blank?

    range = INDICATORS.dig(indicator_type, :range)
    return unless range && !range.cover?(value.to_f)

    errors.add(:value, "está fuera del rango fisiológicamente plausible (#{range})")
  end
end
