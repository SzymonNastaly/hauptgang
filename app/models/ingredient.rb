class Ingredient < ApplicationRecord
  belongs_to :recipe, inverse_of: :ingredients

  validates :raw, presence: true

  def parsed?
    amount.present? || unit.present?
  end
end
