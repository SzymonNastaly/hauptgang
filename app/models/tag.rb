class Tag < ApplicationRecord
  # Associations
  has_many :recipe_tags, dependent: :destroy
  has_many :recipes, through: :recipe_tags

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/, message: "only lowercase letters, numbers, and hyphens" }

  # Callbacks - auto-generate slug from name if not provided
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    self.slug = name.downcase.strip.gsub(/\s+/, "-").gsub(/[^a-z0-9\-]/, "")
  end
end
