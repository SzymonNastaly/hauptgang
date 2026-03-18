class MealPlanEntry < ApplicationRecord
  belongs_to :meal_plan
  belongs_to :recipe
  belongs_to :proposed_by_user, class_name: "User", optional: true
  has_many :votes, class_name: "MealPlanVote", dependent: :destroy

  validates :recipe_id, uniqueness: { scope: :meal_plan_id }
  validate :recipe_belongs_to_same_cookbook

  private

  def recipe_belongs_to_same_cookbook
    return unless recipe && meal_plan
    return if recipe.cookbook_id == meal_plan.cookbook_id

    errors.add(:recipe, "must belong to the same cookbook as the meal plan")
  end
end
