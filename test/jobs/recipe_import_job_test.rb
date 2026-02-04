require "test_helper"

class RecipeImportJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @recipe = recipes(:one)
    @recipe.update!(import_status: :pending, name: "Placeholder")
  end

  test "updates recipe with extracted data on success" do
    html = <<~HTML
      <html>
      <head>
        <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Imported Recipe",
            "recipeIngredient": ["2 cups flour", "1 egg"],
            "recipeInstructions": ["Mix ingredients", "Bake at 350F"],
            "prepTime": "PT15M",
            "cookTime": "PT30M",
            "recipeYield": "4 servings"
          }
        </script>
      </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/recipe")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    RecipeImportJob.perform_now(@user.id, @recipe.id, "https://example.com/recipe")

    @recipe.reload
    assert_equal :completed, @recipe.import_status.to_sym
    assert_equal "Imported Recipe", @recipe.name
    assert_equal [ "2 cups flour", "1 egg" ], @recipe.ingredients
    assert_equal [ "Mix ingredients", "Bake at 350F" ], @recipe.instructions
    assert_equal 15, @recipe.prep_time
    assert_equal 30, @recipe.cook_time
    assert_equal 4, @recipe.servings
    assert_equal "https://example.com/recipe", @recipe.source_url
  end

  test "marks recipe as failed when import fails" do
    stub_request(:get, "https://example.com/recipe")
      .to_return(status: 404, headers: { "Content-Type" => "text/html" })

    RecipeImportJob.perform_now(@user.id, @recipe.id, "https://example.com/recipe")

    @recipe.reload
    assert_equal :failed, @recipe.import_status.to_sym
    assert_not_nil @recipe.error_message
    assert_equal "Import from example.com failed.", @recipe.error_message
  end

  test "marks recipe as failed when no recipe data found" do
    html = "<html><body><h1>Just a regular page</h1></body></html>"

    stub_request(:get, "https://example.com/page")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    stub_llm_no_recipe_found

    RecipeImportJob.perform_now(@user.id, @recipe.id, "https://example.com/page")

    @recipe.reload
    assert_equal :failed, @recipe.import_status.to_sym
    assert_not_nil @recipe.error_message
    assert_equal "Import from example.com failed.", @recipe.error_message
  end

  test "does nothing when recipe no longer exists" do
    deleted_id = @recipe.id
    @recipe.destroy

    assert_nothing_raised do
      RecipeImportJob.perform_now(@user.id, deleted_id, "https://example.com/recipe")
    end
  end

  test "does nothing when user no longer exists" do
    deleted_user_id = @user.id
    @user.destroy

    assert_nothing_raised do
      RecipeImportJob.perform_now(deleted_user_id, @recipe.id, "https://example.com/recipe")
    end
  end

  test "marks recipe as failed on unexpected error and re-raises" do
    stub_request(:get, "https://example.com/recipe")
      .to_raise(StandardError.new("Unexpected"))

    assert_raises(StandardError) do
      RecipeImportJob.perform_now(@user.id, @recipe.id, "https://example.com/recipe")
    end

    @recipe.reload
    assert_equal :failed, @recipe.import_status.to_sym
    assert_not_nil @recipe.error_message
    assert_includes @recipe.error_message, "example.com"
  end
end
