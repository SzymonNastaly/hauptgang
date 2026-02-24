class CookbookMembership < ApplicationRecord
  belongs_to :cookbook
  belongs_to :user

  enum :role, { owner: 0, collaborator: 1 }

  validates :cookbook_id, uniqueness: { scope: :user_id }
  validate :one_owner_per_cookbook, on: :create

  private

  def one_owner_per_cookbook
    return unless owner?
    return unless cookbook&.cookbook_memberships&.where(role: :owner)&.where&.not(id: id)&.exists?

    errors.add(:role, "cookbook already has an owner")
  end
end
