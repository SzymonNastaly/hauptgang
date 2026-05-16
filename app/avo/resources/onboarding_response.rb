class Avo::Resources::OnboardingResponse < Avo::BaseResource
  self.search = {
    query: -> { query.ransack(id_eq: q, device_id_cont: q, m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    field :device_id, as: :text
    field :user, as: :belongs_to
    field :answers, as: :code, language: "json"
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end
end
