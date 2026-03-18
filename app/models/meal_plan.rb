class MealPlan < ApplicationRecord
  belongs_to :cookbook
  belongs_to :selected_entry, class_name: "MealPlanEntry", optional: true
  belongs_to :selected_by_user, class_name: "User", optional: true
  has_many :entries, class_name: "MealPlanEntry", dependent: :destroy

  validates :date, presence: true
  validates :date, uniqueness: { scope: :cookbook_id }
  validate :selected_entry_belongs_to_self

  def selected?
    selected_entry_id.present?
  end

  private

  def selected_entry_belongs_to_self
    return unless selected_entry_id.present?
    return if selected_entry&.meal_plan_id == id

    errors.add(:selected_entry, "must belong to this meal plan")
  end
end
