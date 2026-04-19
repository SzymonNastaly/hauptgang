class Avo::Resources::MealPlanEntry < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :meal_plan, as: :belongs_to
    field :recipe, as: :belongs_to
    field :proposed_by_user, as: :belongs_to
  end
end
