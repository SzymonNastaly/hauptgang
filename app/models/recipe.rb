class Recipe < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, through: :recipe_tags

  # Scopes
  scope :favorited, -> { where(favorite: true) }

  # Validations
  validates :name, presence: true

  # Ensure ingredients and instructions are always arrays
  # Rails 8 with SQLite JSON columns handles this automatically,
  # but we add this for extra safety
  before_validation :ensure_array_fields

  private

  def ensure_array_fields
    self.ingredients ||= []
    self.instructions ||= []
  end
end
