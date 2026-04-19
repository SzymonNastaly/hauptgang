class Avo::Resources::MealPlan < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :date, as: :date
    field :cookbook, as: :belongs_to
    field :selected_entry, as: :belongs_to
    field :selected_by_user, as: :belongs_to
    field :selected_at, as: :date_time
    field :entries, as: :has_many
  end
end
