class DeviceToken < ApplicationRecord
  ACTIVE_WINDOW = 90.days

  ENVIRONMENTS = %w[production sandbox].freeze

  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :environment, inclusion: { in: ENVIRONMENTS }

  scope :active, -> { where("last_used_at IS NULL OR last_used_at > ?", ACTIVE_WINDOW.ago) }

  def self.register!(user:, token:, environment:)
    record = find_or_initialize_by(token: token)
    record.user = user
    record.environment = environment
    record.last_used_at = Time.current
    record.save!
    record
  end
end
