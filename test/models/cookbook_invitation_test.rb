require "test_helper"

class CookbookInvitationTest < ActiveSupport::TestCase
  setup do
    @cookbook = Cookbook.create!(name: "Shared", personal: false)
    CookbookMembership.create!(cookbook: @cookbook, user: users(:one), role: :owner)
  end

  test "auto-generates token on create" do
    invitation = CookbookInvitation.create!(cookbook: @cookbook, inviter: users(:one))

    assert invitation.token.present?
    assert invitation.token.length >= 32
  end

  test "auto-generates expires_at 7 days from now" do
    invitation = CookbookInvitation.create!(cookbook: @cookbook, inviter: users(:one))

    assert_in_delta 7.days.from_now, invitation.expires_at, 5.seconds
  end

  test "token must be unique" do
    invitation1 = CookbookInvitation.create!(cookbook: @cookbook, inviter: users(:one))
    invitation2 = CookbookInvitation.new(
      cookbook: @cookbook,
      inviter: users(:one),
      token: invitation1.token
    )

    assert_not invitation2.valid?
    assert_includes invitation2.errors[:token], "has already been taken"
  end

  test "status enum values" do
    invitation = CookbookInvitation.create!(cookbook: @cookbook, inviter: users(:one))

    assert invitation.pending?

    invitation.accepted!
    assert invitation.accepted?

    invitation.rejected!
    assert invitation.rejected?

    invitation.expired!
    assert invitation.expired?
  end

  test "active scope returns pending non-expired invitations" do
    active = CookbookInvitation.create!(cookbook: @cookbook, inviter: users(:one))
    expired = CookbookInvitation.create!(cookbook: @cookbook, inviter: users(:one))
    expired.update!(expires_at: 1.day.ago)
    accepted = CookbookInvitation.create!(cookbook: @cookbook, inviter: users(:one))
    accepted.accepted!

    active_invitations = CookbookInvitation.active

    assert_includes active_invitations, active
    assert_not_includes active_invitations, expired
    assert_not_includes active_invitations, accepted
  end

  test "time_expired? returns true when past expires_at" do
    invitation = CookbookInvitation.create!(cookbook: @cookbook, inviter: users(:one))
    invitation.update!(expires_at: 1.day.ago)

    assert invitation.time_expired?
  end

  test "time_expired? returns false when before expires_at" do
    invitation = CookbookInvitation.create!(cookbook: @cookbook, inviter: users(:one))

    assert_not invitation.time_expired?
  end
end
