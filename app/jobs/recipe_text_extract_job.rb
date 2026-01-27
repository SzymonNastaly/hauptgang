class RecipeTextExtractJob < ApplicationJob
  queue_as :default

  def perform(user_id, recipe_id, text)
    user = User.find_by(id: user_id)
    return unless user

    recipe = user.recipes.find_by(id: recipe_id)
    return unless recipe
    return if recipe.completed?

    result = RecipeLlmService.new(text, prompt_type: :raw_text).extract

    if result.success?
      recipe.update!(result.recipe_attributes.merge(import_status: :completed))
    else
      recipe.update!(import_status: :failed)
      Rails.logger.error "[RecipeTextExtractJob] Extraction failed for recipe #{recipe_id}: #{result.error}"
    end
  rescue => e
    recipe&.update(import_status: :failed)
    Rails.logger.error "[RecipeTextExtractJob] Unexpected error for recipe #{recipe_id}: #{e.class} - #{e.message}"
    raise
  end
end
