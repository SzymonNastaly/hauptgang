require "test_helper"

class PendingNotificationTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @collab = users(:two)
    @cookbook = Cookbook.create!(name: "Shared", personal: false)
    CookbookMembership.create!(cookbook: @cookbook, user: @owner, role: :owner)
    CookbookMembership.create!(cookbook: @cookbook, user: @collab, role: :collaborator)
    DeviceToken.register!(user: @collab, token: "collab-device-1", environment: "sandbox")
  end

  test "skips personal cookbooks" do
    personal = @owner.personal_cookbook

    assert_no_enqueued_jobs only: DeliverPendingNotificationJob do
      PendingNotification.record_event!(
        cookbook: personal, actor: @owner, category: :shopping_list, event: { name: "X" }
      )
    end
    assert_equal 0, PendingNotification.count
  end

  test "skips actor (does not notify themselves)" do
    PendingNotification.record_event!(
      cookbook: @cookbook, actor: @owner, category: :shopping_list, event: { name: "Milk" }
    )

    assert_equal 1, PendingNotification.count
    assert_equal @collab, PendingNotification.first.recipient
    assert_equal @owner, PendingNotification.first.actor
  end

  test "coalesces multiple events into a single bucket" do
    assert_enqueued_jobs 1, only: DeliverPendingNotificationJob do
      3.times do |i|
        PendingNotification.record_event!(
          cookbook: @cookbook, actor: @owner, category: :shopping_list, event: { name: "item-#{i}" }
        )
      end
    end

    assert_equal 1, PendingNotification.count
    pending = PendingNotification.first
    assert_equal 3, pending.payload.size
    assert_not_nil pending.delivery_scheduled_at
  end

  test "combines meal_plan adds and votes in one bucket" do
    PendingNotification.record_event!(
      cookbook: @cookbook, actor: @owner, category: :meal_plan_activity,
      event: { kind: "entry_added", recipe_name: "Pasta" }
    )
    PendingNotification.record_event!(
      cookbook: @cookbook, actor: @owner, category: :meal_plan_activity,
      event: { kind: "vote", recipe_name: "Pasta" }
    )

    assert_equal 1, PendingNotification.where(category: "meal_plan_activity").count
    assert_equal 2, PendingNotification.first.payload.size
  end

  test "skips recipients with no active device tokens" do
    silent = User.create!(email_address: "silent@example.com", password: "password123")
    CookbookMembership.create!(cookbook: @cookbook, user: silent, role: :collaborator)

    PendingNotification.record_event!(
      cookbook: @cookbook, actor: @owner, category: :shopping_list, event: { name: "Milk" }
    )

    recipient_ids = PendingNotification.where(category: "shopping_list").pluck(:recipient_id)
    assert_includes recipient_ids, @collab.id
    assert_not_includes recipient_ids, silent.id
  end

  test "retries once on RecordNotUnique then appends to the existing row" do
    existing = PendingNotification.create!(
      cookbook: @cookbook, actor: @owner, recipient: @collab,
      category: "shopping_list", payload: [ { "name" => "Milk" } ],
      delivery_scheduled_at: Time.current + PendingNotification::DEBOUNCE_WINDOW
    )

    # Simulate the race: the first attempt's `lock` call raises RecordNotUnique
    # (as if a concurrent inserter committed between our SELECT and our save).
    # The retry then delegates to the real implementation via PendingNotification.all.lock,
    # which routes through Relation#lock and bypasses this override.
    call_count = 0
    PendingNotification.define_singleton_method(:lock) do |*args, **kwargs|
      call_count += 1
      raise ActiveRecord::RecordNotUnique.new("simulated race") if call_count == 1
      PendingNotification.all.lock
    end

    begin
      PendingNotification.append_events(
        cookbook_id: @cookbook.id, recipient_id: @collab.id,
        actor_id: @owner.id, category: "shopping_list",
        events: [ { "name" => "Bread" } ]
      )
    ensure
      PendingNotification.singleton_class.send(:remove_method, :lock)
    end

    assert_equal 2, call_count, "expected one retry"
    assert_equal 2, existing.reload.payload.size
  end

  test "shopping_list and meal_plan_activity buckets are separate" do
    PendingNotification.record_event!(
      cookbook: @cookbook, actor: @owner, category: :shopping_list, event: { name: "Milk" }
    )
    PendingNotification.record_event!(
      cookbook: @cookbook, actor: @owner, category: :meal_plan_activity,
      event: { kind: "entry_added", recipe_name: "Pasta" }
    )

    assert_equal 2, PendingNotification.count
  end
end
