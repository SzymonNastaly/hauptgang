require "test_helper"

class CookbookMembershipTest < ActiveSupport::TestCase
  test "valid with cookbook, user, and role" do
    cookbook = Cookbook.create!(name: "Shared", personal: false)
    membership = CookbookMembership.new(cookbook: cookbook, user: users(:one), role: :owner)

    assert membership.valid?
  end

  test "enforces uniqueness of cookbook_id and user_id" do
    existing = cookbook_memberships(:one_owns_personal)
    duplicate = CookbookMembership.new(
      cookbook: existing.cookbook,
      user: existing.user,
      role: :collaborator
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:cookbook_id], "has already been taken"
  end

  test "allows same user in different cookbooks" do
    new_cookbook = Cookbook.create!(name: "Shared", personal: false)
    membership = CookbookMembership.new(
      cookbook: new_cookbook,
      user: users(:one),
      role: :collaborator
    )

    assert membership.valid?
  end

  test "owner enum value" do
    membership = cookbook_memberships(:one_owns_personal)

    assert membership.owner?
    assert_not membership.collaborator?
  end

  test "collaborator enum value" do
    cookbook = Cookbook.create!(name: "Shared", personal: false)
    CookbookMembership.create!(cookbook: cookbook, user: users(:one), role: :owner)
    membership = CookbookMembership.create!(cookbook: cookbook, user: users(:two), role: :collaborator)

    assert membership.collaborator?
    assert_not membership.owner?
  end

  test "validates one owner per cookbook" do
    cookbook = Cookbook.create!(name: "Shared", personal: false)
    CookbookMembership.create!(cookbook: cookbook, user: users(:one), role: :owner)

    second_owner = CookbookMembership.new(cookbook: cookbook, user: users(:two), role: :owner)

    assert_not second_owner.valid?
    assert_includes second_owner.errors[:role], "cookbook already has an owner"
  end
end
