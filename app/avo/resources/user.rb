class Avo::Resources::User < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :email_address, as: :text
    field :pro, as: :boolean
    field :cookbooks, as: :has_many, through: :cookbook_memberships
    field :recipes, as: :has_many
    field :shopping_list_items, as: :has_many
  end
end
