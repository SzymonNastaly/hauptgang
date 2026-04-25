class User < ApplicationRecord
  include ImportLimitable

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :device_tokens, dependent: :destroy
  has_many :cookbook_memberships, dependent: :delete_all
  has_many :cookbooks, through: :cookbook_memberships
  has_many :recipes, dependent: :nullify
  has_many :shopping_list_items, dependent: :nullify

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true

  after_create :create_personal_cookbook!
  before_destroy :destroy_owned_cookbooks!, prepend: true

  def personal_cookbook
    cookbooks.personal.first
  end

  def shared_cookbook
    cookbooks.shared.first
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id email_address]
  end

  private

  def create_personal_cookbook!
    cookbook = Cookbook.create!(name: "My Recipes", personal: true)
    cookbook_memberships.create!(cookbook: cookbook, role: :owner)
  end

  def destroy_owned_cookbooks!
    # Must run before dependent callbacks. Destroys owned cookbooks (cascading to their recipes
    # and shopping list items). DB-level ON DELETE CASCADE handles memberships cleanup.
    cookbook_memberships.where(role: :owner).includes(:cookbook).find_each do |membership|
      membership.cookbook.destroy!
    end
  end
end
