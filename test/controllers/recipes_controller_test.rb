require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @recipe = recipes(:one)          # belongs to @user
    @other_recipe = recipes(:two)    # belongs to @other_user
    sign_in_as @user
  end

  # ===================
  # BASIC CRUD TESTS
  # ===================
  # These verify that standard operations work for the owner.

  test "should get index" do
    get recipes_url
    assert_response :success
  end

  test "index only shows current user's recipes" do
    get recipes_url

    # Should see own recipes
    assert_match @recipe.name, response.body
    assert_match recipes(:three).name, response.body  # Also belongs to @user

    # Should NOT see other user's recipes
    assert_no_match @other_recipe.name, response.body
  end

  test "sidebar recipe count shows only current user's recipes" do
    get recipes_url

    # User one has 2 recipes (one and three), user two has 1 recipe (two)
    # Sidebar should show "2", not "3" (total)
    user_recipe_count = @user.recipes.count
    total_recipes = Recipe.count

    assert_equal 2, user_recipe_count, "Fixture assumption: user one should have 2 recipes"
    assert_equal 3, total_recipes, "Fixture assumption: total recipes should be 3"

    # Use data-testid for stable test selectors
    assert_select "[data-testid='all-recipes-count']", text: user_recipe_count.to_s
  end

  test "sidebar favorites count shows only current user's favorites" do
    get recipes_url

    # User one has 1 favorite (three), user two has 1 favorite (two)
    # Sidebar should show "1", not "2" (total)
    user_favorites_count = @user.recipes.favorited.count
    total_favorites = Recipe.where(favorite: true).count

    assert_equal 1, user_favorites_count, "Fixture assumption: user one should have 1 favorite"
    assert_equal 2, total_favorites, "Fixture assumption: total favorites should be 2"

    # Use data-testid for stable test selectors
    assert_select "[data-testid='favorites-count']", text: user_favorites_count.to_s
  end

  test "should get new" do
    get new_recipe_url
    assert_response :success
  end

  test "should create recipe" do
    assert_difference("Recipe.count") do
      post recipes_url, params: {
        recipe: {
          name: "New Test Recipe",
          ingredients: [ "ingredient1", "ingredient2" ],
          instructions: [ "step1", "step2" ],
          servings: 4
        }
      }
    end

    # Verify the recipe belongs to the current user
    created_recipe = Recipe.last
    assert_equal @user, created_recipe.user
    assert_redirected_to recipe_url(created_recipe)
  end

  test "should show recipe" do
    get recipe_url(@recipe)
    assert_response :success
  end

  test "should get edit" do
    get edit_recipe_url(@recipe)
    assert_response :success
  end

  test "should update recipe" do
    patch recipe_url(@recipe), params: {
      recipe: {
        name: "Updated Name",
        ingredients: @recipe.ingredients,
        instructions: @recipe.instructions,
        servings: @recipe.servings
      }
    }
    assert_redirected_to recipe_url(@recipe)

    # Verify the update persisted
    @recipe.reload
    assert_equal "Updated Name", @recipe.name
  end

  test "should destroy recipe" do
    assert_difference("Recipe.count", -1) do
      delete recipe_url(@recipe)
    end

    assert_redirected_to recipes_url
  end

  # ===================
  # AUTHORIZATION TESTS
  # ===================
  # These are the MOST IMPORTANT tests for security!
  # They verify users cannot access each other's data.

  test "cannot show other user's recipe" do
    get recipe_url(@other_recipe)

    # Should get 404 (record not found), not 403 (forbidden)
    # This is intentional: we don't want to reveal that the recipe exists
    assert_response :not_found
  end

  test "cannot edit other user's recipe" do
    get edit_recipe_url(@other_recipe)
    assert_response :not_found
  end

  test "cannot update other user's recipe" do
    original_name = @other_recipe.name

    patch recipe_url(@other_recipe), params: {
      recipe: { name: "Hacked!" }
    }

    assert_response :not_found

    # Verify the recipe was NOT changed
    @other_recipe.reload
    assert_equal original_name, @other_recipe.name
  end

  test "cannot destroy other user's recipe" do
    assert_no_difference("Recipe.count") do
      delete recipe_url(@other_recipe)
    end

    assert_response :not_found
  end

  # ===================
  # AUTHENTICATION TESTS
  # ===================
  # These verify that unauthenticated users can't access recipes.

  test "requires authentication for index" do
    sign_out
    get recipes_url
    assert_redirected_to new_session_path
  end

  test "requires authentication for show" do
    sign_out
    get recipe_url(@recipe)
    assert_redirected_to new_session_path
  end

  test "requires authentication for new" do
    sign_out
    get new_recipe_url
    assert_redirected_to new_session_path
  end

  test "requires authentication for create" do
    sign_out
    assert_no_difference("Recipe.count") do
      post recipes_url, params: { recipe: { name: "Test" } }
    end
    assert_redirected_to new_session_path
  end

  test "requires authentication for edit" do
    sign_out
    get edit_recipe_url(@recipe)
    assert_redirected_to new_session_path
  end

  test "requires authentication for update" do
    sign_out
    patch recipe_url(@recipe), params: { recipe: { name: "Test" } }
    assert_redirected_to new_session_path
  end

  test "requires authentication for destroy" do
    sign_out
    assert_no_difference("Recipe.count") do
      delete recipe_url(@recipe)
    end
    assert_redirected_to new_session_path
  end

  # ===================
  # FEATURE TESTS
  # ===================
  # These test specific features like favorites and filtering.

  test "toggle_favorite changes favorite status" do
    assert_not @recipe.favorite

    patch toggle_favorite_recipe_url(@recipe)

    @recipe.reload
    assert @recipe.favorite
  end

  test "cannot toggle favorite on other user's recipe" do
    original_favorite = @other_recipe.favorite

    patch toggle_favorite_recipe_url(@other_recipe)

    assert_response :not_found
    @other_recipe.reload
    assert_equal original_favorite, @other_recipe.favorite
  end

  test "favorites filter only shows favorited recipes" do
    get recipes_url(view: "favorites")
    assert_response :success

    # recipes(:three) is favorited, recipes(:one) is not
    assert_match recipes(:three).name, response.body
    assert_no_match recipes(:one).name, response.body
  end
end
