class RecipeImportJob < ApplicationJob
  queue_as :default

  def perform(user_id, recipe_id, source_url)
    user = User.find_by(id: user_id)
    return unless user

    recipe = user.recipes.find_by(id: recipe_id)
    return unless recipe
    return if recipe.completed?

    result = RecipeImporter.new(source_url).import

    if result.success?
      recipe.update!(result.recipe_attributes.merge(import_status: :completed))
    else
      error_message = build_error_message(source_url, result.error_code)
      recipe.update!(
        import_status: :failed,
        error_message: error_message
      )
      Rails.logger.error "[RecipeImportJob] Import failed for recipe #{recipe_id}: #{result.error}"
    end
  rescue => e
    if recipe
      error_message = build_error_message(source_url, :unexpected_error)
      recipe.update(
        import_status: :failed,
        error_message: error_message
      )
    end
    Rails.logger.error "[RecipeImportJob] Unexpected error for recipe #{recipe_id}: #{e.class} - #{e.message}"
    raise
  end

  private

  def build_error_message(url, error_code)
    domain = extract_domain(url)

    # Generic message covers all failure types
    # (no JSON-LD, LLM timeout, fetch errors, etc.)
    "Import from #{domain} failed - page is not supported or doesn't contain a recipe"
  end

  def extract_domain(url)
    return "unknown source" if url.blank?

    uri = URI.parse(url)
    uri.host || "unknown source"
  rescue URI::InvalidURIError
    "unknown source"
  end
end
