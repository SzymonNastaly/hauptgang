require "test_helper"

class Api::V1::CookbookInvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @invitee = users(:two)
    _token_record, @owner_token = ApiToken.generate_for(@owner)
    _token_record, @invitee_token = ApiToken.generate_for(@invitee)
    @owner_headers = { "Authorization" => "Bearer #{@owner_token}" }
    @invitee_headers = { "Authorization" => "Bearer #{@invitee_token}" }

    @shared = Cookbook.create!(name: "Family Recipes", personal: false)
    CookbookMembership.create!(cookbook: @shared, user: @owner, role: :owner)
  end

  # ===================
  # CREATE INVITATION
  # ===================

  test "create generates invitation for owned shared cookbook" do
    post api_v1_cookbook_invitations_url(@shared), headers: @owner_headers, as: :json

    assert_response :created
    json = response.parsed_body
    assert json["token"].present?
    assert json["invite_url"].present?
    assert json["expires_at"].present?
    assert_includes json["invite_url"], json["token"]
  end

  test "create returns 403 for non-owner" do
    CookbookMembership.create!(cookbook: @shared, user: @invitee, role: :collaborator)

    post api_v1_cookbook_invitations_url(@shared), headers: @invitee_headers, as: :json

    assert_response :forbidden
  end

  test "create returns 422 for personal cookbook" do
    post api_v1_cookbook_invitations_url(@owner.personal_cookbook), headers: @owner_headers, as: :json

    assert_response :unprocessable_entity
  end

  test "create returns 404 for cookbook user is not a member of" do
    post api_v1_cookbook_invitations_url(cookbooks(:two_personal)), headers: @owner_headers, as: :json

    assert_response :not_found
  end

  test "create expires previous pending invitations" do
    first_invitation = CookbookInvitation.create!(cookbook: @shared, inviter: @owner)
    assert first_invitation.pending?

    post api_v1_cookbook_invitations_url(@shared), headers: @owner_headers, as: :json

    assert_response :created
    assert first_invitation.reload.expired?
  end

  # ===================
  # SHOW INVITATION (preview)
  # ===================

  test "show returns invitation preview" do
    invitation = CookbookInvitation.create!(cookbook: @shared, inviter: @owner)

    get api_v1_invitation_url(invitation.token), headers: @invitee_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "Family Recipes", json["cookbook_name"]
    assert_equal @owner.email_address, json["inviter_email"]
    assert_equal "pending", json["status"]
  end

  test "show returns 404 for invalid token" do
    get api_v1_invitation_url("nonexistent-token"), headers: @invitee_headers, as: :json

    assert_response :not_found
  end

  # ===================
  # ACCEPT INVITATION
  # ===================

  test "accept adds user as collaborator" do
    invitation = CookbookInvitation.create!(cookbook: @shared, inviter: @owner)

    post accept_api_v1_invitation_url(invitation.token), headers: @invitee_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal @shared.id, json["cookbook_id"]
    assert_equal "Family Recipes", json["cookbook_name"]

    assert CookbookMembership.exists?(cookbook: @shared, user: @invitee, role: :collaborator)
    assert invitation.reload.accepted?
  end

  test "accept returns 422 when user already a member" do
    CookbookMembership.create!(cookbook: @shared, user: @invitee, role: :collaborator)
    invitation = CookbookInvitation.create!(cookbook: @shared, inviter: @owner)

    post accept_api_v1_invitation_url(invitation.token), headers: @invitee_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "You are already a member of this cookbook", response.parsed_body["error"]
  end

  test "accept returns 422 when user already has a shared cookbook" do
    other_shared = Cookbook.create!(name: "Other Shared", personal: false)
    CookbookMembership.create!(cookbook: other_shared, user: @invitee, role: :owner)

    invitation = CookbookInvitation.create!(cookbook: @shared, inviter: @owner)

    post accept_api_v1_invitation_url(invitation.token), headers: @invitee_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "You already have a shared cookbook", response.parsed_body["error"]
  end

  test "accept returns 404 for expired invitation" do
    invitation = CookbookInvitation.create!(cookbook: @shared, inviter: @owner)
    invitation.update!(expires_at: 1.day.ago)

    post accept_api_v1_invitation_url(invitation.token), headers: @invitee_headers, as: :json

    assert_response :not_found
  end

  test "accept returns 404 for already accepted invitation" do
    invitation = CookbookInvitation.create!(cookbook: @shared, inviter: @owner)
    invitation.accepted!

    post accept_api_v1_invitation_url(invitation.token), headers: @invitee_headers, as: :json

    assert_response :not_found
  end

  # ===================
  # REJECT INVITATION
  # ===================

  test "reject marks invitation as rejected" do
    invitation = CookbookInvitation.create!(cookbook: @shared, inviter: @owner)

    post reject_api_v1_invitation_url(invitation.token), headers: @invitee_headers, as: :json

    assert_response :no_content
    assert invitation.reload.rejected?
  end

  test "reject returns 404 for expired invitation" do
    invitation = CookbookInvitation.create!(cookbook: @shared, inviter: @owner)
    invitation.update!(expires_at: 1.day.ago)

    post reject_api_v1_invitation_url(invitation.token), headers: @invitee_headers, as: :json

    assert_response :not_found
  end
end
