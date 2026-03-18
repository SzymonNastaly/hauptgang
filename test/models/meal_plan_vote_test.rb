require "test_helper"

class MealPlanVoteTest < ActiveSupport::TestCase
  test "belongs to an entry" do
    vote = meal_plan_votes(:vote_one_on_today_entry)

    assert_not_nil vote.meal_plan_entry
    assert_equal meal_plan_entries(:today_entry_one), vote.meal_plan_entry
  end

  test "belongs to a user" do
    vote = meal_plan_votes(:vote_one_on_today_entry)

    assert_not_nil vote.user
    assert_equal users(:one), vote.user
  end

  test "user can only vote once per entry" do
    duplicate = MealPlanVote.new(
      meal_plan_entry: meal_plan_entries(:today_entry_one),
      user: users(:one)
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "different users can vote on same entry" do
    vote = MealPlanVote.new(
      meal_plan_entry: meal_plan_entries(:today_entry_one),
      user: users(:two)
    )

    assert vote.valid?
  end
end
