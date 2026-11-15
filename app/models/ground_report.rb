class GroundReport < ApplicationRecord
  belongs_to :alert

  STATUSES = %w[sent acknowledged replied].freeze

  validates :summary, presence: true
  validates :sent_day, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :for_day, ->(date) { where(sent_day: date) }
  scope :awaiting_reply, -> { where(status: "sent") }

  def self.create_for_alert(alert, summary: nil)
    delay_seconds = CommDelay.seconds_for(alert.astronaut)
    create!(
      alert: alert,
      summary: summary.presence || default_summary(alert),
      sent_day: Date.current,
      status: "sent",
      earliest_reply_at: Time.current + delay_seconds.seconds
    )
  end

  def reply_overdue?
    earliest_reply_at.present? && Time.current > earliest_reply_at
  end

  def self.default_summary(alert)
    "Alert for #{alert.indicator.label}: #{alert.level} (#{alert.basis})"
  end
end
