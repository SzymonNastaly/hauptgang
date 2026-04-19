class Avo::Resources::ShoppingListItem < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :client_id, as: :text
    field :cookbook, as: :belongs_to
    field :user, as: :belongs_to
    field :source_recipe, as: :belongs_to
    field :checked_at, as: :date_time
  end
end
