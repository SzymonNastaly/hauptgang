class RecipeImageExtractJob < ApplicationJob
  queue_as :default

  def perform(user_id, recipe_id)
    user = User.find_by(id: user_id)
    return unless user

    recipe = user.recipes.find_by(id: recipe_id)
    return unless recipe
    return if recipe.completed?

    unless recipe.import_image.attached?
      recipe.update!(import_status: :failed, error_message: "Import failed.")
      Rails.logger.error "[RecipeImageExtractJob] Missing import image for recipe #{recipe_id}"
      return
    end

    result = recipe.import_image.blob.open do |file|
      RecipeImageLlmService.new(file.path).extract
    end

    if result.success?
      recipe.update!(result.recipe_attributes.merge(import_status: :completed))
    else
      recipe.update!(
        import_status: :failed,
        error_message: "Import failed."
      )
      Rails.logger.error "[RecipeImageExtractJob] Extraction failed for recipe #{recipe_id}: #{result.error}"
    end
  rescue => e
    recipe&.update(
      import_status: :failed,
      error_message: "Import failed."
    )
    Rails.logger.error "[RecipeImageExtractJob] Unexpected error for recipe #{recipe_id}: #{e.class} - #{e.message}"
    raise
  end
end
