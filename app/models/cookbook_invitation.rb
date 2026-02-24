class CookbookInvitation < ApplicationRecord
  belongs_to :cookbook
  belongs_to :inviter, class_name: "User"

  enum :status, { pending: 0, accepted: 1, rejected: 2, expired: 3 }

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { pending.where("expires_at > ?", Time.current) }

  before_validation :generate_token_and_expiry, on: :create

  def time_expired?
    expires_at < Time.current
  end

  private

  def generate_token_and_expiry
    self.token ||= SecureRandom.urlsafe_base64(32)
    self.expires_at ||= 7.days.from_now
  end
end
