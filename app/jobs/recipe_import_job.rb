class RecipeImportJob < ApplicationJob
  queue_as :default

  def perform(user_id, recipe_id, source_url)
    user = User.find_by(id: user_id)
    return unless user

    recipe = user.recipes.find_by(id: recipe_id)
    return unless recipe

    result = RecipeImporter.new(source_url).import

    if result.success?
      attrs = result.recipe_attributes
      recipe.update!(
        name: attrs[:name],
        ingredients: attrs[:ingredients],
        instructions: attrs[:instructions],
        prep_time: attrs[:prep_time],
        cook_time: attrs[:cook_time],
        servings: attrs[:servings],
        notes: attrs[:notes],
        source_url: attrs[:source_url],
        import_status: :completed
      )
    else
      recipe.update!(import_status: :failed)
      Rails.logger.error "[RecipeImportJob] Import failed for recipe #{recipe_id}: #{result.error}"
    end
  rescue => e
    recipe&.update(import_status: :failed)
    Rails.logger.error "[RecipeImportJob] Unexpected error for recipe #{recipe_id}: #{e.class} - #{e.message}"
    raise
  end
end
