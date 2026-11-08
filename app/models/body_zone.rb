# Zona clickeable del cuerpo 3D.
# related_indicators (jsonb) guarda un array de indicator_type que alimentan la zona.
# El nombre debe coincidir con el nombre del mesh en Three.js (head, chest, abdomen, limbs).
class BodyZone < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :related_indicators, presence: true
  validate :related_indicators_must_be_known

  # Estado agregado de la zona: el peor status entre sus indicadores.
  # Un solo indicador rojo pinta la zona de rojo (criterio conservador en vuelo).
  def status_for(readings_by_type)
    statuses = related_indicators.filter_map { |type| readings_by_type[type]&.status }
    return "green" if statuses.empty?

    %w[red yellow green].find { |candidate| statuses.include?(candidate) } || "green"
  end

  private

  def related_indicators_must_be_known
    return if related_indicators.blank?

    unknown = Array(related_indicators) - HealthReading::INDICATOR_TYPES
    return if unknown.empty?

    errors.add(:related_indicators, "contiene indicadores desconocidos: #{unknown.join(', ')}")
  end
end
