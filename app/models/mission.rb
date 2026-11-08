# Misión espacial. Agrupa a los astronautas y sus lecturas de salud.
# Permite que la herramienta opere con varias misiones simultáneamente
# (por ejemplo, Gateway, tránsito a Marte o un análogo en Tierra).
class Mission < ApplicationRecord
  STATUSES = %w[active planned completed archived].freeze

  has_many :astronauts, dependent: :restrict_with_error
  has_many :health_readings, through: :astronauts

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }
end
