require "test_helper"

class MealPlanEntryTest < ActiveSupport::TestCase
  # ===================
  # ASSOCIATION TESTS
  # ===================

  test "belongs to a meal plan" do
    entry = meal_plan_entries(:today_entry_one)

    assert_not_nil entry.meal_plan
    assert_equal meal_plans(:today_plan), entry.meal_plan
  end

  test "belongs to a recipe" do
    entry = meal_plan_entries(:today_entry_one)

    assert_not_nil entry.recipe
    assert_equal recipes(:one), entry.recipe
  end

  test "proposed_by_user is optional" do
    entry = MealPlanEntry.new(
      meal_plan: meal_plans(:today_plan),
      recipe: recipes(:three),
      proposed_by_user: nil
    )

    # Recipe :three is already in today_plan via fixture, use a new recipe
    cookbook = cookbooks(:one_personal)
    recipe = cookbook.recipes.create!(name: "Test Entry Recipe", user: users(:one))
    entry.recipe = recipe

    assert entry.valid?
  end

  test "has many votes" do
    entry = meal_plan_entries(:today_entry_one)

    assert_includes entry.votes, meal_plan_votes(:vote_one_on_today_entry)
  end

  test "votes are destroyed when entry is destroyed" do
    entry = meal_plan_entries(:today_entry_one)

    assert_difference "MealPlanVote.count", -1 do
      entry.destroy
    end
  end

  # ===================
  # VALIDATION TESTS
  # ===================

  test "recipe must be unique per meal plan" do
    existing = meal_plan_entries(:today_entry_one)
    duplicate = MealPlanEntry.new(
      meal_plan: existing.meal_plan,
      recipe: existing.recipe,
      proposed_by_user: users(:one)
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:recipe_id], "has already been taken"
  end

  test "recipe must belong to same cookbook as meal plan" do
    entry = MealPlanEntry.new(
      meal_plan: meal_plans(:today_plan),
      recipe: recipes(:two),
      proposed_by_user: users(:one)
    )

    assert_not entry.valid?
    assert_includes entry.errors[:recipe], "must belong to the same cookbook as the meal plan"
  end

  # ===================
  # RECIPE DELETION RESTRICTION
  # ===================

  test "recipe deletion is blocked while meal plan entries exist" do
    recipe = recipes(:one)
    entry_ids = recipe.meal_plan_entries.pluck(:id)
    assert entry_ids.any?

    assert_no_difference "MealPlanEntry.count" do
      assert_not recipe.destroy
    end

    assert_match(/dependent/i, recipe.errors[:base].join(" "))
    assert_equal entry_ids.sort, MealPlanEntry.where(id: entry_ids).pluck(:id).sort
  end
end
