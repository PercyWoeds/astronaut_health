# Checklist rápido previo a una actividad extravehicular (EVA).
# Incluye "egress fitness" del estudio CIPHER: la prueba de salida de cápsula
# debe estar completada antes de autorizar la simulación.
class PreEvaCheck < ApplicationRecord
  belongs_to :astronaut

  before_validation :set_checked_at

  scope :recent_first, -> { order(checked_at: :desc, id: :desc) }

  # Checks operativos mínimos de la EVA.
  def core_ready?
    o2_ok? && pressure_ok? && fatigue_ok?
  end

  # Checklist completo, incluyendo Egress Fitness (CIPHER).
  def ready?
    core_ready? && egress_fitness_completed?
  end

  private

  def set_checked_at
    self.checked_at ||= Time.current
  end
end
