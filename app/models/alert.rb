class Alert < ApplicationRecord
  belongs_to :astronaut
  belongs_to :indicator

  LEVELS = %w[watch action].freeze
  BASES = %w[absolute baseline].freeze
  STATUSES = %w[open acknowledged resolved].freeze

  validates :level, inclusion: { in: LEVELS }
  validates :basis, inclusion: { in: BASES }
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: "open") }
  scope :action, -> { where(level: "action") }

  def self.open_for_astronaut(astronaut)
    where(astronaut: astronaut, status: "open")
  end

  def resolve!
    update!(status: "resolved")
  end

  def acknowledge!
    update!(status: "acknowledged")
  end
end
