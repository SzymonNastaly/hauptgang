class DeliverPendingNotificationJob < ApplicationJob
  queue_as :default

  INVALID_TOKEN_REASONS = %w[BadDeviceToken Unregistered DeviceTokenNotForTopic TopicDisallowed].freeze

  def perform(pending_notification_id)
    snapshot = PendingNotification.transaction do
      pending = PendingNotification.lock.find_by(id: pending_notification_id)
      next nil if pending.nil?

      data = {
        payload: pending.payload || [],
        cookbook: pending.cookbook,
        actor: pending.actor,
        recipient: pending.recipient,
        category: pending.category
      }
      pending.destroy!
      data
    end

    return if snapshot.nil? || snapshot[:payload].empty?

    aps = build_aps(category: snapshot[:category], cookbook: snapshot[:cookbook], actor: snapshot[:actor], events: snapshot[:payload])
    custom = { cookbook_id: snapshot[:cookbook].id, category: snapshot[:category] }

    snapshot[:recipient].device_tokens.active.find_each do |device_token|
      result = Apns::Client.push(
        token: device_token.token,
        environment: device_token.environment,
        aps: aps,
        custom: custom
      )

      if !result.ok? && INVALID_TOKEN_REASONS.include?(result.reason)
        device_token.destroy
      end
    end
  end

  private

  def build_aps(category:, cookbook:, actor:, events:)
    title = "#{actor_display_name(actor)} · #{cookbook.name}"
    body = build_body(category, events)
    { alert: { title: title, body: body } }
  end

  def build_body(category, events)
    case category
    when "shopping_list"
      count = events.size
      "Added #{count} #{'item'.pluralize(count)} to the shopping list"
    when "meal_plan_activity"
      adds = events.count { |e| e["kind"] == "entry_added" }
      votes = events.count { |e| e["kind"] == "vote" }
      parts = []
      parts << "added #{adds} #{'recipe'.pluralize(adds)}" if adds.positive?
      parts << "voted on #{votes} #{'recipe'.pluralize(votes)}" if votes.positive?
      sentence = parts.join(" and ")
      sentence.empty? ? "Updated the meal plan" : sentence.capitalize
    else
      "New activity"
    end
  end

  def actor_display_name(actor)
    actor.email_address.to_s.split("@").first.presence || "Someone"
  end
end
