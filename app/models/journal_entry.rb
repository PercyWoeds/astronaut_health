# Entrada del diario de a bordo. Contramedida del riesgo psicosocial de
# aislamiento/confinamiento identificado por el NASA HRP.
class JournalEntry < ApplicationRecord
  belongs_to :astronaut

  validates :content, presence: true, length: { maximum: 5_000 }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
end
