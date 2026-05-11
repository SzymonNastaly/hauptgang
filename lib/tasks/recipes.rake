namespace :recipes do
  desc "Backfill structured ingredient rows for existing recipes from the legacy snapshot"
  task backfill_ingredients: :environment do
    Recipe.find_each do |recipe|
      next if recipe.ingredients.any?
      BackfillRecipeIngredientsJob.perform_later(recipe.id)
    end
    puts "Enqueued backfill jobs."
  end
end
