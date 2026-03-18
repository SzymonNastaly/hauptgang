class MealPlanVote < ApplicationRecord
  belongs_to :meal_plan_entry
  belongs_to :user

  validates :user_id, uniqueness: { scope: :meal_plan_entry_id }
end
