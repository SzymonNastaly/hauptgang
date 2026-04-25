class PendingNotification < ApplicationRecord
  DEBOUNCE_WINDOW = 6.minutes

  CATEGORIES = %w[shopping_list meal_plan_activity].freeze

  belongs_to :cookbook
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User"

  validates :category, inclusion: { in: CATEGORIES }

  # Records one or more events in the pending bucket for every other member of the cookbook.
  # Coalesces with any in-flight bucket so at most one DeliverPendingNotificationJob
  # is scheduled per (cookbook, recipient, actor, category) per DEBOUNCE_WINDOW.
  #
  # category: one of CATEGORIES
  # events:   an Array of small Hashes describing the events (used later to build the body)
  def self.record_events!(cookbook:, actor:, category:, events:)
    return if cookbook.personal?

    normalized_events = Array(events).map(&:as_json)
    return if normalized_events.empty?

    recipient_ids = cookbook.cookbook_memberships
                            .where.not(user_id: actor.id)
                            .joins(user: :device_tokens)
                            .merge(DeviceToken.active)
                            .distinct
                            .pluck(:user_id)
    return if recipient_ids.empty?

    recipient_ids.each do |recipient_id|
      append_events(
        cookbook_id: cookbook.id,
        recipient_id: recipient_id,
        actor_id: actor.id,
        category: category.to_s,
        events: normalized_events
      )
    end
  end

  def self.record_event!(cookbook:, actor:, category:, event:)
    record_events!(cookbook: cookbook, actor: actor, category: category, events: [ event ])
  end

  def self.append_events(cookbook_id:, recipient_id:, actor_id:, category:, events:)
    attempts = 0
    begin
      transaction do
        record = lock.find_or_initialize_by(
          cookbook_id: cookbook_id,
          recipient_id: recipient_id,
          actor_id: actor_id,
          category: category
        )

        record.payload = (record.payload || []) + events

        should_schedule = record.delivery_scheduled_at.nil?
        record.delivery_scheduled_at = Time.current + DEBOUNCE_WINDOW if should_schedule
        record.save!

        if should_schedule
          DeliverPendingNotificationJob.set(wait: DEBOUNCE_WINDOW).perform_later(record.id)
        end
      end
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      retry if attempts < 2
      raise
    end
  end
end
