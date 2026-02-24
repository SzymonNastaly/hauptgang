class Cookbook < ApplicationRecord
  has_many :cookbook_memberships, dependent: :destroy
  has_many :users, through: :cookbook_memberships
  has_many :recipes, dependent: :destroy
  has_many :shopping_list_items, dependent: :destroy
  has_many :cookbook_invitations, dependent: :destroy

  scope :personal, -> { where(personal: true) }
  scope :shared, -> { where(personal: false) }

  validates :name, presence: true

  def owner
    cookbook_memberships.find_by(role: :owner)&.user
  end

  def owner?(user)
    cookbook_memberships.exists?(user: user, role: :owner)
  end
end
