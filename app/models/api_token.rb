class ApiToken < ApplicationRecord
  belongs_to :user

  TOKEN_EXPIRY = 90.days
  LAST_USED_THRESHOLD = 5.minutes

  scope :active, -> {
    where(revoked_at: nil)
      .where("expires_at > ?", Time.current)
  }

  # Generate a new token for a user
  # Returns [token_record, raw_token] - the raw token is only available once
  def self.generate_for(user, name: nil)
    raw_token = SecureRandom.urlsafe_base64(32)
    token = user.api_tokens.create!(
      token_digest: digest(raw_token),
      name: name,
      expires_at: TOKEN_EXPIRY.from_now
    )
    [ token, raw_token ]
  end

  # Find a token by its raw value
  def self.find_by_raw_token(raw_token)
    return nil if raw_token.blank?
    active.find_by(token_digest: digest(raw_token))
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def active?
    !revoked? && !expired?
  end

  # Update last_used_at, throttled to reduce DB writes
  def touch_last_used!
    return if last_used_at && last_used_at > LAST_USED_THRESHOLD.ago
    update_column(:last_used_at, Time.current)
  end

  private

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end
end
