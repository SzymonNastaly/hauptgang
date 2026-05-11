require "test_helper"

class BackfillRecipeIngredientsJobTest < ActiveSupport::TestCase
  setup do
    @recipe = recipes(:one)
    @recipe.ingredients.destroy_all
    BackfillRecipeIngredientsJob::LegacyRecipeIngredient.where(recipe_id: @recipe.id).delete_all
  end

  test "creates ingredient rows from legacy snapshot and enqueues parse job" do
    BackfillRecipeIngredientsJob::LegacyRecipeIngredient.create!(
      recipe_id: @recipe.id,
      ingredients: [ "2 cups flour", "1 tsp salt", "" ]
    )

    assert_enqueued_with(job: ParseRecipeIngredientsJob, args: [ @recipe.id ]) do
      BackfillRecipeIngredientsJob.perform_now(@recipe.id)
    end

    rows = @recipe.reload.ingredients.order(:position)
    assert_equal 2, rows.length
    assert_equal "2 cups flour", rows[0].raw
    assert_equal "2 cups flour", rows[0].name
    assert_equal 0, rows[0].position
    assert_equal "1 tsp salt", rows[1].raw
    assert_equal 1, rows[1].position
  end

  test "skips when ingredients already exist" do
    @recipe.ingredients.create!(position: 0, raw: "existing", name: "existing")
    BackfillRecipeIngredientsJob::LegacyRecipeIngredient.create!(
      recipe_id: @recipe.id,
      ingredients: [ "should not be used" ]
    )

    assert_no_enqueued_jobs(only: ParseRecipeIngredientsJob) do
      BackfillRecipeIngredientsJob.perform_now(@recipe.id)
    end

    assert_equal [ "existing" ], @recipe.reload.ingredients.map(&:raw)
  end

  test "no-ops when no legacy snapshot exists" do
    assert_no_enqueued_jobs(only: ParseRecipeIngredientsJob) do
      BackfillRecipeIngredientsJob.perform_now(@recipe.id)
    end
    assert_equal 0, @recipe.reload.ingredients.count
  end

  test "no-ops when recipe is missing" do
    assert_nothing_raised do
      BackfillRecipeIngredientsJob.perform_now(0)
    end
  end
end
