require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  # ===================
  # ASSOCIATION TESTS
  # ===================

  test "belongs to a user" do
    recipe = recipes(:one)

    # The recipe should have a user
    assert_not_nil recipe.user
    assert_equal users(:one), recipe.user
  end

  test "can access recipes through user" do
    user = users(:one)

    # User should have recipes (the inverse of belongs_to)
    assert_includes user.recipes, recipes(:one)
    assert_includes user.recipes, recipes(:three)
    assert_not_includes user.recipes, recipes(:two)  # belongs to user :two
  end

  # ===================
  # VALIDATION TESTS
  # ===================

  test "requires a name" do
    recipe = Recipe.new(
      user: users(:one),
      name: nil  # Missing required field
    )

    assert_not recipe.valid?
    assert_includes recipe.errors[:name], "can't be blank"
  end

  test "requires a user" do
    recipe = Recipe.new(
      name: "Test Recipe",
      user: nil  # Missing required association
    )

    assert_not recipe.valid?
    assert_includes recipe.errors[:user], "must exist"
  end

  test "valid with minimal attributes" do
    recipe = Recipe.new(
      name: "Simple Recipe",
      user: users(:one)
    )

    assert recipe.valid?
  end

  # ===================
  # SCOPE TESTS
  # ===================

  test "favorited scope returns only favorites" do
    user_one_recipes = users(:one).recipes

    # User one has: :one (not favorite) and :three (favorite)
    favorites = user_one_recipes.favorited

    assert_includes favorites, recipes(:three)
    assert_not_includes favorites, recipes(:one)
  end

  # ===================
  # CALLBACK TESTS
  # ===================

  test "ensures ingredients is an array" do
    recipe = Recipe.new(
      name: "Test",
      user: users(:one),
      ingredients: nil
    )

    recipe.valid?  # Triggers before_validation callback

    assert_equal [], recipe.ingredients
  end

  test "ensures instructions is an array" do
    recipe = Recipe.new(
      name: "Test",
      user: users(:one),
      instructions: nil
    )

    recipe.valid?  # Triggers before_validation callback

    assert_equal [], recipe.instructions
  end

  # ===================
  # COVER IMAGE TESTS
  # ===================

  test "can attach a cover image" do
    recipe = recipes(:one)

    recipe.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )

    assert recipe.cover_image.attached?
  end

  test "cover image is purged when recipe is destroyed" do
    recipe = recipes(:one)
    recipe.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )
    recipe.save!

    blob_id = recipe.cover_image.blob.id

    # purge_later enqueues a job, so we need to perform it
    perform_enqueued_jobs do
      recipe.destroy
    end

    assert_nil ActiveStorage::Blob.find_by(id: blob_id)
  end

  test "cover image has thumbnail variant" do
    recipe = recipes(:one)
    recipe.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )

    assert recipe.cover_image.variant(:thumbnail).present?
  end

  test "cover image has display variant" do
    recipe = recipes(:one)
    recipe.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )

    assert recipe.cover_image.variant(:display).present?
  end

  # ===================
  # DEPENDENT DESTROY TEST
  # ===================

  test "recipes are deleted when user is deleted" do
    user = users(:one)
    recipe_ids = user.recipes.pluck(:id)

    assert_not_empty recipe_ids, "User should have recipes for this test"

    # When we delete the user...
    user.destroy

    # ...their recipes should be gone too
    recipe_ids.each do |id|
      assert_nil Recipe.find_by(id: id), "Recipe #{id} should be deleted"
    end
  end
end
