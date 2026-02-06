class Recipe < ApplicationRecord
  # Enums
  enum :import_status, { pending: 0, completed: 1, failed: 2 }

  # Associations
  belongs_to :user
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, through: :recipe_tags

  # File attachments
  has_one_attached :cover_image, dependent: :purge_later do |attachable|
    # Thumbnail for recipe cards/lists (400px wide, optimized for mobile)
    attachable.variant :thumbnail, resize_to_limit: [ 400, 300 ], format: :webp, saver: { quality: 80 }
    # Display size for recipe detail page (800px wide)
    attachable.variant :display, resize_to_limit: [ 800, 600 ], format: :webp, saver: { quality: 85 }
  end
  has_one_attached :import_image, dependent: :purge_later

  # Scopes
  scope :favorited, -> { where(favorite: true) }

  # Validations
  validates :name, presence: true
  validate :acceptable_cover_image
  validate :acceptable_import_image

  # Ensure ingredients and instructions are always arrays
  # Rails 8 with SQLite JSON columns handles this automatically,
  # but we add this for extra safety
  before_validation :ensure_array_fields

  private

  def ensure_array_fields
    self.ingredients ||= []
    self.instructions ||= []
  end

  def acceptable_cover_image
    return unless cover_image.attached?

    if cover_image.blob.byte_size > 15.megabytes
      errors.add(:cover_image, "is too big (max 15MB)")
    end

    unless cover_image.blob.content_type&.start_with?("image/")
      errors.add(:cover_image, "must be an image")
    end
  end

  def acceptable_import_image
    return unless import_image.attached?

    if import_image.blob.byte_size > 15.megabytes
      errors.add(:import_image, "is too big (max 15MB)")
    end

    unless import_image.blob.content_type&.start_with?("image/")
      errors.add(:import_image, "must be an image")
    end
  end
end
