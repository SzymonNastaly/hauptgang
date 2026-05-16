class OnboardingResponse < ApplicationRecord
  belongs_to :user, optional: true

  validates :device_id, presence: true, uniqueness: true

  # Upsert answers for the given device_id, merging into any existing record.
  def self.record!(device_id:, answers:)
    id = device_id.to_s.strip
    raise ArgumentError, "device_id is required" if id.blank?

    record = find_or_initialize_by(device_id: id)
    record.answers = (record.answers || {}).merge(answers.to_h)
    record.save!
    record
  end

  # Attach any prior anonymous response for this device to the given user.
  def self.link_to_user!(device_id:, user:)
    id = device_id.to_s.strip
    return if id.blank? || user.nil?

    where(device_id: id, user_id: nil).update_all(user_id: user.id, updated_at: Time.current)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id device_id user_id created_at updated_at]
  end
end
