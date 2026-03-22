# frozen_string_literal: true

# Fresh user + personal cookbook + recipe with no meal-plan entries, for job tests that
# destroy the user or recipe without fighting fixture meal plans.
module JobIsolatedRecipeHelper
  private

  def create_job_test_user_and_recipe(name:, import_status: :pending, **recipe_attrs)
    user = User.create!(
      email_address: "job-test-#{SecureRandom.hex(8)}@example.com",
      password: "password"
    )
    recipe = user.personal_cookbook.recipes.create!(
      { user: user, name: name, import_status: import_status }.merge(recipe_attrs)
    )
    [ user, recipe ]
  end
end
