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
    title = build_title(actor, cookbook)
    body = build_body(category, events)
    { alert: { title: title, body: body } }
  end

  def build_title(actor, cookbook)
    name = actor.name.to_s.strip
    name.empty? ? %("#{cookbook.name}") : %(#{name} in "#{cookbook.name}")
  end

  def build_body(category, events)
    case category
    when "shopping_list"
      count = events.size
      "Added #{count} #{'item'.pluralize(count)} to the shopping list"
    when "meal_plan_activity"
      adds = events.count { |e| e["kind"] == "entry_added" }
      votes = events.count { |e| e["kind"] == "vote" }
      if adds.positive? && votes.positive?
        "Added #{adds} #{'recipe'.pluralize(adds)} and voted on #{votes} in the meal plan"
      elsif adds.positive?
        "Added #{adds} #{'recipe'.pluralize(adds)} to the meal plan"
      elsif votes.positive?
        "Voted on #{votes} #{'recipe'.pluralize(votes)} in the meal plan"
      else
        "Updated the meal plan"
      end
    else
      "New activity"
    end
  end
end
