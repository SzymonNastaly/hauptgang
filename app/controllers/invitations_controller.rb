class InvitationsController < ApplicationController
  skip_before_action :require_authentication

  def show
    @token = params[:token]
    @invitation = CookbookInvitation.includes(:cookbook, :inviter).find_by(token: @token)
  end
end
