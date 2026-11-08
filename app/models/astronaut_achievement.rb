# Join entre astronauta y logro. awarded_at permite auditar cuándo se obtuvo.
class AstronautAchievement < ApplicationRecord
  belongs_to :astronaut
  belongs_to :achievement

  validates :achievement_id, uniqueness: { scope: :astronaut_id }

  before_validation :set_awarded_at

  private

  def set_awarded_at
    self.awarded_at ||= Time.current
  end
end
