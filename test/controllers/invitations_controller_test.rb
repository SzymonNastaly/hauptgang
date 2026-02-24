require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @cookbook = Cookbook.create!(name: "Shared Kitchen", personal: false)
    CookbookMembership.create!(cookbook: @cookbook, user: @owner, role: :owner)
  end

  test "show renders invitation page for valid pending invitation" do
    invitation = CookbookInvitation.create!(cookbook: @cookbook, inviter: @owner)

    get invite_url(invitation.token)

    assert_response :success
    assert_select "h1", "Cookbook Invitation"
    assert_match "Shared Kitchen", response.body
    assert_match @owner.email_address, response.body
  end

  test "show renders expired message for time-expired invitation" do
    invitation = CookbookInvitation.create!(cookbook: @cookbook, inviter: @owner)
    invitation.update_column(:expires_at, 1.day.ago)

    get invite_url(invitation.token)

    assert_response :success
    assert_match "expired", response.body
  end

  test "show renders accepted message for accepted invitation" do
    invitation = CookbookInvitation.create!(cookbook: @cookbook, inviter: @owner)
    invitation.accepted!

    get invite_url(invitation.token)

    assert_response :success
    assert_match "already been accepted", response.body
  end

  test "show renders invalid message for nonexistent token" do
    get invite_url("nonexistent-token-abc123")

    assert_response :success
    assert_match "no longer valid", response.body
  end
end
