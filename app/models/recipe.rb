class Recipe < ApplicationRecord
  # Associations
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, through: :recipe_tags

  # Scopes
  scope :favorited, -> { where(favorite: true) }

  # Validations
  validates :name, presence: true
end
