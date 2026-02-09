class ShoppingListItem < ApplicationRecord
  belongs_to :user
  belongs_to :source_recipe, class_name: "Recipe", optional: true

  validates :name, presence: true
  validates :client_id, presence: true, uniqueness: { scope: :user_id }

  scope :unchecked, -> { where(checked_at: nil) }
  scope :checked, -> { where.not(checked_at: nil) }
  scope :stale_checked, -> { where("checked_at < ?", 1.hour.ago) }

  def self.cleanup_stale_checked_for(user)
    user.shopping_list_items.checked.stale_checked.destroy_all
  end
end
