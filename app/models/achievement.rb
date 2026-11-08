# Logro de gamificación desbloqueable por el astronauta.
class Achievement < ApplicationRecord
  has_many :astronaut_achievements, dependent: :destroy
  has_many :astronauts, through: :astronaut_achievements

  validates :name, presence: true, uniqueness: true
  validates :points, numericality: { greater_than_or_equal_to: 0 }
end
