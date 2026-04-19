class Avo::Resources::Cookbook < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :personal, as: :boolean
    field :users, as: :has_many, through: :cookbook_memberships
    field :meal_plans, as: :has_many
    field :recipes, as: :has_many
    field :shopping_list_items, as: :has_many
    field :cookbook_invitations, as: :has_many
  end
end
