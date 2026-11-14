class Baseline < ApplicationRecord
  belongs_to :astronaut
  belongs_to :indicator

  validates :mean, numericality: true
  validates :std, numericality: { greater_than_or_equal_to: 0 }
  validates :samples, numericality: { only_integer: true, greater_than: 0 }
  validates :source, inclusion: { in: %w[pre-flight preflight in-flight] }

  def z_score(value)
    return nil if std.zero?
    (value.to_f - mean) / std
  end

  def self.for_astronaut_and_indicator(astronaut, indicator)
    where(astronaut: astronaut, indicator: indicator).first
  end
end
