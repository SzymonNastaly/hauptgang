class RecipeTag < ApplicationRecord
  belongs_to :recipe
  belongs_to :tag

  # Ensure a recipe can't have the same tag twice
  validates :tag_id, uniqueness: { scope: :recipe_id }
end
