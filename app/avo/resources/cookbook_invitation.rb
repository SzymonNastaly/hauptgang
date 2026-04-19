class Avo::Resources::CookbookInvitation < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  self.search = {
    query: -> { query.ransack(id_eq: q, token_cont: q, m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    field :cookbook, as: :belongs_to
    field :inviter, as: :belongs_to
    field :token, as: :text
    field :status, as: :select, enum: ::CookbookInvitation.statuses
    field :expires_at, as: :date_time
  end
end
