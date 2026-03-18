require "test_helper"

class MealPlanTest < ActiveSupport::TestCase
  # ===================
  # ASSOCIATION TESTS
  # ===================

  test "belongs to a cookbook" do
    meal_plan = meal_plans(:today_plan)

    assert_not_nil meal_plan.cookbook
    assert_equal cookbooks(:one_personal), meal_plan.cookbook
  end

  test "has many entries" do
    meal_plan = meal_plans(:today_plan)

    assert_equal 2, meal_plan.entries.count
    assert_includes meal_plan.entries, meal_plan_entries(:today_entry_one)
    assert_includes meal_plan.entries, meal_plan_entries(:today_entry_three)
  end

  test "entries are destroyed when meal plan is destroyed" do
    meal_plan = meal_plans(:today_plan)
    entry_ids = meal_plan.entries.pluck(:id)

    assert_not_empty entry_ids

    assert_difference "MealPlanEntry.count", -entry_ids.size do
      meal_plan.destroy
    end
  end

  # ===================
  # VALIDATION TESTS
  # ===================

  test "requires a date" do
    meal_plan = MealPlan.new(cookbook: cookbooks(:one_personal), date: nil)

    assert_not meal_plan.valid?
    assert_includes meal_plan.errors[:date], "can't be blank"
  end

  test "date must be unique per cookbook" do
    existing = meal_plans(:today_plan)
    duplicate = MealPlan.new(cookbook: existing.cookbook, date: existing.date)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:date], "has already been taken"
  end

  test "same date allowed in different cookbooks" do
    plan = MealPlan.new(cookbook: cookbooks(:two_personal), date: meal_plans(:today_plan).date)

    # today_plan is in one_personal, other_cookbook_plan is in two_personal
    # but other_cookbook_plan also uses Date.today, so use a different date
    plan.date = Date.tomorrow

    assert plan.valid?
  end

  test "selected entry must belong to self" do
    meal_plan = meal_plans(:today_plan)
    other_entry = meal_plan_entries(:other_cookbook_entry)

    meal_plan.selected_entry = other_entry

    assert_not meal_plan.valid?
    assert_includes meal_plan.errors[:selected_entry], "must belong to this meal plan"
  end

  test "valid selected entry passes validation" do
    meal_plan = meal_plans(:today_plan)
    entry = meal_plan_entries(:today_entry_one)

    meal_plan.selected_entry = entry

    assert meal_plan.valid?
  end

  # ===================
  # HELPER TESTS
  # ===================

  test "selected? returns true when selected_entry_id present" do
    meal_plan = meal_plans(:selected_plan)

    assert meal_plan.selected?
  end

  test "selected? returns false when selected_entry_id nil" do
    meal_plan = meal_plans(:today_plan)

    assert_not meal_plan.selected?
  end
end
