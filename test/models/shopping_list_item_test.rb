require "test_helper"

class ShoppingListItemTest < ActiveSupport::TestCase
  test "valid with all attributes" do
    item = ShoppingListItem.new(
      user: users(:one),
      client_id: "new-client-id",
      name: "Apples"
    )

    assert item.valid?
  end

  test "requires name" do
    item = ShoppingListItem.new(
      user: users(:one),
      client_id: "new-client-id",
      name: nil
    )

    assert_not item.valid?
    assert_includes item.errors[:name], "can't be blank"
  end

  test "requires client_id" do
    item = ShoppingListItem.new(
      user: users(:one),
      client_id: nil,
      name: "Apples"
    )

    assert_not item.valid?
    assert_includes item.errors[:client_id], "can't be blank"
  end

  test "client_id must be unique per user" do
    existing = shopping_list_items(:unchecked_milk)

    duplicate = ShoppingListItem.new(
      user: existing.user,
      client_id: existing.client_id,
      name: "Duplicate"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:client_id], "has already been taken"
  end

  test "same client_id allowed for different users" do
    item = ShoppingListItem.new(
      user: users(:two),
      client_id: shopping_list_items(:unchecked_milk).client_id,
      name: "Milk"
    )

    assert item.valid?
  end

  test "belongs to user" do
    item = shopping_list_items(:unchecked_milk)

    assert_equal users(:one), item.user
  end

  test "belongs to source_recipe optionally" do
    with_recipe = shopping_list_items(:unchecked_bread)
    without_recipe = shopping_list_items(:unchecked_milk)

    assert_equal recipes(:one), with_recipe.source_recipe
    assert_nil without_recipe.source_recipe
  end

  test "unchecked scope returns items without checked_at" do
    user_items = users(:one).shopping_list_items.unchecked

    assert_includes user_items, shopping_list_items(:unchecked_milk)
    assert_includes user_items, shopping_list_items(:unchecked_bread)
    assert_not_includes user_items, shopping_list_items(:checked_eggs)
    assert_not_includes user_items, shopping_list_items(:stale_checked_butter)
  end

  test "checked scope returns items with checked_at" do
    user_items = users(:one).shopping_list_items.checked

    assert_includes user_items, shopping_list_items(:checked_eggs)
    assert_includes user_items, shopping_list_items(:stale_checked_butter)
    assert_not_includes user_items, shopping_list_items(:unchecked_milk)
  end

  test "stale_checked scope returns items checked more than 1 hour ago" do
    user_items = users(:one).shopping_list_items.stale_checked

    assert_includes user_items, shopping_list_items(:stale_checked_butter)
    assert_not_includes user_items, shopping_list_items(:checked_eggs)
    assert_not_includes user_items, shopping_list_items(:unchecked_milk)
  end

  test "cleanup_stale_checked_for destroys stale checked items" do
    user = users(:one)
    stale = shopping_list_items(:stale_checked_butter)
    recent = shopping_list_items(:checked_eggs)

    ShoppingListItem.cleanup_stale_checked_for(user)

    assert_raises(ActiveRecord::RecordNotFound) { stale.reload }
    assert_nothing_raised { recent.reload }
  end

  test "cleanup_stale_checked_for does not affect other users" do
    other_item = shopping_list_items(:other_user_item)

    ShoppingListItem.cleanup_stale_checked_for(users(:one))

    assert_nothing_raised { other_item.reload }
  end
end
