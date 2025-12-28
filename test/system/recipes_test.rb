require "application_system_test_case"

class RecipesSystemTest < ApplicationSystemTestCase
  # ===================
  # SETUP
  # ===================

  setup do
    @user = users(:one)
    @recipe = recipes(:one)  # Pasta Carbonara, belongs to @user
  end

  # ===================
  # AUTHENTICATION FLOW
  # ===================

  test "user can sign in and see their recipes" do
    visit recipes_path

    # Should be redirected to login
    assert_current_path new_session_path

    # Sign in
    sign_in_via_ui(@user)

    # Should see recipes index with their recipes
    assert_testid "recipes-grid"

    # Look for recipe card specifically (more reliable than just text)
    assert_testid "recipe-card-#{@recipe.id}"
  end

  test "unauthenticated user is redirected to login" do
    visit recipes_path
    assert_current_path new_session_path
    assert_testid "login-form"
  end

  # ===================
  # RECIPE CRUD FLOWS
  # ===================

  test "user can create a new recipe" do
    sign_in_via_ui(@user)
    visit recipes_path

    # Click the new recipe button in the topbar (more reliable than the grid card)
    click_testid "new-recipe-button"

    # Fill in the form
    fill_in_testid "recipe-name-input", with: "My Test Recipe"

    # Add an ingredient (click adds a new field outside the template)
    click_testid "add-ingredient-button"
    # Find the ingredient field that's NOT in a template (visible one)
    ingredient_field = all("input[name='recipe[ingredients][]']", visible: true).last
    ingredient_field.set("2 cups flour")

    # Add an instruction
    click_testid "add-instruction-button"
    # Find the instruction field that's visible
    instruction_field = all("textarea[name='recipe[instructions][]']", visible: true).last
    instruction_field.set("Mix all ingredients")

    # Save
    click_testid "save-recipe-button"

    # Should see success and the new recipe
    assert_text "Recipe was successfully created"
    assert_text "My Test Recipe"
  end

  test "user can view a recipe" do
    sign_in_via_ui(@user)
    visit recipes_path

    # Click on a recipe card (use visible: :all for complex layouts)
    click_testid "recipe-card-#{@recipe.id}", visible: :all

    # Should see the recipe details
    assert_text @recipe.name
    assert_testid "edit-recipe-link"
  end

  test "user can edit a recipe" do
    sign_in_via_ui(@user)
    visit recipe_path(@recipe)

    click_testid "edit-recipe-link"

    # Update the name
    fill_in_testid "recipe-name-input", with: "Updated Recipe Name"
    click_testid "save-recipe-button"

    # Should see success
    assert_text "Recipe was successfully updated"
    assert_text "Updated Recipe Name"
  end

  test "user can delete a recipe" do
    sign_in_via_ui(@user)
    visit recipe_path(@recipe)

    # Accept the confirmation dialog
    accept_confirm do
      click_testid "delete-recipe-button"
    end

    # Should be back at index
    assert_text "Recipe was successfully destroyed"
    assert_no_text @recipe.name
  end

  # ===================
  # AUTHORIZATION FLOWS
  # ===================

  test "user cannot see other users recipes in the list" do
    other_recipe = recipes(:two)  # Belongs to user :two

    sign_in_via_ui(@user)
    visit recipes_path

    # Should see own recipe card
    assert_testid "recipe-card-#{@recipe.id}"

    # Should NOT see other user's recipe card
    assert_no_testid "recipe-card-#{other_recipe.id}"
  end

  # ===================
  # EMPTY STATE
  # ===================

  test "user sees empty state when no recipes" do
    # Delete all recipes for this user
    @user.recipes.destroy_all

    sign_in_via_ui(@user)
    visit recipes_path

    assert_testid "empty-state"
    assert_text "No recipes found"
    assert_testid "new-recipe-link"
  end
end
