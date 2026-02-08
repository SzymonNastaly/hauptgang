require "faraday"
require "stringio"

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
      attach_cover_image(recipe, result.cover_image_url) if result.cover_image_url.present?
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

  def attach_cover_image(recipe, image_url)
    response = cover_image_client.get(image_url)

    unless response.success?
      Rails.logger.info "[RecipeImportJob] Cover image fetch failed (HTTP #{response.status}) for recipe #{recipe.id}"
      return
    end

    content_type = response.headers["content-type"].to_s
    unless content_type.start_with?("image/")
      Rails.logger.info "[RecipeImportJob] Cover image invalid content type for recipe #{recipe.id}: #{content_type}"
      return
    end

    if response.body.bytesize > 15.megabytes
      Rails.logger.info "[RecipeImportJob] Cover image too large for recipe #{recipe.id}: #{response.body.bytesize} bytes"
      return
    end

    filename = extract_filename(image_url)
    recipe.cover_image.attach(
      io: StringIO.new(response.body),
      filename: filename,
      content_type: content_type
    )
  rescue => e
    Rails.logger.error "[RecipeImportJob] Cover image attach failed for recipe #{recipe.id}: #{e.class} - #{e.message}"
  end

  def cover_image_client
    Faraday.new do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
      f.headers["User-Agent"] = "Mozilla/5.0 (compatible; Hauptgang Recipe Importer)"
    end
  end

  def extract_filename(url)
    uri = URI.parse(url)
    name = File.basename(uri.path.to_s)
    name.presence || "cover-image"
  rescue URI::InvalidURIError
    "cover-image"
  end

  def build_error_message(url, error_code)
    domain = extract_domain(url)
    "Import from #{domain} failed."
  end

  def extract_domain(url)
    return "unknown source" if url.blank?

    uri = URI.parse(url)
    host = uri.host || "unknown source"
    host.delete_prefix("www.")
  rescue URI::InvalidURIError
    "unknown source"
  end
end
