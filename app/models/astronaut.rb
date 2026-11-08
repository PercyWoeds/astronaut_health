# Astronauta participante en una misión espacial.
# Es la entidad raíz: acumula lecturas de salud y logros de gamificación.
class Astronaut < ApplicationRecord
  belongs_to :mission

  has_many :health_readings, dependent: :destroy
  has_many :astronaut_achievements, dependent: :destroy
  has_many :achievements, through: :astronaut_achievements

  validates :name, presence: true, uniqueness: { scope: :mission_id }

  # Puntos totales obtenidos por todos los logros desbloqueados.
  def total_points
    achievements.sum(:points)
  end

  # Devuelve un Hash { indicator_type => HealthReading } con la lectura
  # más reciente de cada indicador. Evita N+1 con una sola consulta.
  def latest_readings
    health_readings
      .order(measured_at: :desc, id: :desc)
      .to_a
      .each_with_object({}) do |reading, memo|
        memo[reading.indicator_type] ||= reading
      end
  end
end
