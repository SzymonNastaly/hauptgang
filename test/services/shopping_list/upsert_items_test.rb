require "test_helper"

class ShoppingList::UpsertItemsTest < ActiveSupport::TestCase
  test "returns error when items are empty" do
    user = users(:one)

    result = ShoppingList::UpsertItems.new(user: user, items: []).call

    assert_not result.success?
    assert_equal [ { client_id: nil, error: "No items provided" } ], result.errors
    assert_equal [], result.items
  end

  test "creates items with valid attributes" do
    user = users(:one)
    recipe = recipes(:one)

    result = ShoppingList::UpsertItems.new(
      user: user,
      items: [ { client_id: "client-1", name: "Milk", source_recipe_id: recipe.id } ]
    ).call

    assert result.success?
    assert_equal 1, result.items.size
    assert_equal "Milk", result.items.first.name
    assert_equal "client-1", result.items.first.client_id
    assert_equal recipe.id, result.items.first.source_recipe_id
  end

  test "returns error when client_id or name is missing" do
    user = users(:one)

    result = ShoppingList::UpsertItems.new(
      user: user,
      items: [ { client_id: "", name: "" } ]
    ).call

    assert_not result.success?
    assert_equal 1, result.errors.size
    assert_equal "client_id and name are required", result.errors.first[:error]
  end

  test "returns error when source_recipe_id does not belong to user" do
    user = users(:one)
    other_recipe = recipes(:two)

    result = ShoppingList::UpsertItems.new(
      user: user,
      items: [ { client_id: "client-2", name: "Bread", source_recipe_id: other_recipe.id } ]
    ).call

    assert_not result.success?
    assert_equal "Recipe not found", result.errors.first[:error]
  end

  test "creates item without source_recipe_id" do
    user = users(:one)

    result = ShoppingList::UpsertItems.new(
      user: user,
      items: [ { client_id: "no-recipe", name: "Butter" } ]
    ).call

    assert result.success?
    assert_nil result.items.first.source_recipe_id
  end

  test "rolls back all items when any item is invalid" do
    user = users(:one)

    assert_no_difference "ShoppingListItem.count" do
      result = ShoppingList::UpsertItems.new(
        user: user,
        items: [
          { client_id: "valid-1", name: "Flour" },
          { client_id: "", name: "" },
          { client_id: "valid-2", name: "Sugar" }
        ]
      ).call

      assert_not result.success?
      assert_equal [], result.items
      assert_equal 1, result.errors.size
    end
  end

  test "upserts by client_id and updates checked_at" do
    user = users(:one)
    existing = ShoppingListItem.create!(
      user: user,
      client_id: "client-3",
      name: "Old Name",
      checked_at: nil
    )

    checked_time = Time.current
    result = ShoppingList::UpsertItems.new(
      user: user,
      items: [ { client_id: "client-3", name: "New Name", checked_at: checked_time } ]
    ).call

    assert result.success?
    assert_equal 1, result.items.size
    assert_equal existing.id, result.items.first.id
    assert_equal "New Name", result.items.first.name
    assert_equal checked_time.to_i, result.items.first.checked_at.to_i
  end

  test "retries on concurrent duplicate client_id" do
    user = users(:one)
    existing = shopping_list_items(:unchecked_milk)

    raised = false

    service = ShoppingList::UpsertItems.new(
      user: user,
      items: [ { client_id: existing.client_id, name: "Updated Milk" } ]
    )

    original_save = ShoppingListItem.instance_method(:save)

    ShoppingListItem.define_method(:save) do |*args, **kwargs|
      if !raised && client_id == existing.client_id
        raised = true
        raise ActiveRecord::RecordNotUnique, "duplicate"
      end
      original_save.bind(self).call(*args, **kwargs)
    end

    result = service.call

    assert result.success?
    assert_equal "Updated Milk", result.items.first.name
    assert_equal existing.id, result.items.first.id
  ensure
    ShoppingListItem.define_method(:save, original_save)
  end

  test "returns error when recipe is deleted between validation and save" do
    user = users(:one)
    recipe = user.recipes.create!(name: "Temp Recipe")

    original_save = ShoppingListItem.instance_method(:save)
    raised = false

    ShoppingListItem.define_method(:save) do |*args, **kwargs|
      if !raised && source_recipe_id.present?
        raised = true
        raise ActiveRecord::InvalidForeignKey, "FK violation"
      end
      original_save.bind(self).call(*args, **kwargs)
    end

    result = ShoppingList::UpsertItems.new(
      user: user,
      items: [ { client_id: "fk-race", name: "Ingredient", source_recipe_id: recipe.id } ]
    ).call

    assert_not result.success?
    assert_equal "Recipe not found", result.errors.first[:error]
  ensure
    ShoppingListItem.define_method(:save, original_save)
  end

  test "unchecks item by upserting with blank checked_at" do
    user = users(:one)
    existing = ShoppingListItem.create!(
      user: user,
      client_id: "client-uncheck",
      name: "Checked Item",
      checked_at: Time.current
    )

    result = ShoppingList::UpsertItems.new(
      user: user,
      items: [ { client_id: "client-uncheck", name: "Checked Item", checked_at: "" } ]
    ).call

    assert result.success?
    assert_nil result.items.first.checked_at
    assert_equal existing.id, result.items.first.id
  end
end
