require "base64"
require "time"

module Api
  module V1
    class RecipesController < BaseController
      class ImportLimitReachedError < StandardError; end

      before_action :check_import_limit!, only: [ :import, :extract_from_text, :extract_from_image ]
      after_action :cleanup_old_failed_recipes, only: [ :index ]

      rescue_from ImportLimitReachedError, with: :render_import_limit_reached

      def index
        recipes = current_user.recipes.with_attached_cover_image.includes(:tags)
        recipes = recipes.favorited if params[:favorites] == "true"
        recipes = recipes.order(updated_at: :desc)

        # Track first fetch of failed recipes (before rendering)
        track_failed_recipe_fetches(recipes)

        render json: recipes.map { |recipe| recipe_list_json(recipe) }
      end

      def batch
        limit = normalize_limit(params[:limit])
        recipes = current_user.recipes.with_attached_cover_image.includes(:tags)
        recipes = recipes.order(updated_at: :asc, id: :asc)

        if params[:cursor].present?
          cursor = decode_cursor(params[:cursor])
          return render json: { error: "Invalid cursor" }, status: :unprocessable_entity if cursor.nil?

          updated_at, id = cursor
          recipes = recipes.where("updated_at > ? OR (updated_at = ? AND id > ?)", updated_at, updated_at, id)
        end

        batch = recipes.limit(limit)
        next_cursor = batch.any? ? encode_cursor(batch.last.updated_at, batch.last.id) : nil

        render json: {
          recipes: batch.map { |recipe| recipe_detail_json(recipe) },
          next_cursor: next_cursor
        }
      end

      def show
        recipe = current_user.recipes.with_attached_cover_image.includes(:tags).find(params[:id])
        render json: recipe_detail_json(recipe)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Recipe not found" }, status: :not_found
      end

      def destroy
        recipe = current_user.recipes.find(params[:id])
        recipe.destroy!
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Recipe not found" }, status: :not_found
      rescue ActiveRecord::RecordNotDestroyed
        render json: { error: "Could not delete recipe" }, status: :unprocessable_entity
      end

      def import
        url = params[:url].to_s.strip
        if url.blank?
          return render json: { error: "URL is required" }, status: :unprocessable_entity
        end

        validation = RecipeImporters::UrlValidator.new(url).validate
        unless validation.success?
          return render json: { error: validation.error }, status: :unprocessable_entity
        end

        recipe = current_user.with_lock do
          check_import_limit_locked!
          current_user.recipes.create!(
            name: "Importing...",
            source_url: url,
            import_status: :pending
          )
        end

        RecipeImportJob.perform_later(current_user.id, recipe.id, url)

        render json: { id: recipe.id, import_status: recipe.import_status }, status: :accepted
      end

      def extract_from_text
        text = params[:text].to_s.strip
        if text.blank?
          return render json: { error: "Text is required" }, status: :unprocessable_entity
        end
        if text.length > 50_000
          return render json: { error: "Text too long (max 50,000 chars)" }, status: :unprocessable_entity
        end

        recipe = current_user.with_lock do
          check_import_limit_locked!
          current_user.recipes.create!(
            name: "Importing...",
            import_status: :pending
          )
        end

        RecipeTextExtractJob.perform_later(current_user.id, recipe.id, text)

        render json: { id: recipe.id, import_status: recipe.import_status }, status: :accepted
      end

      def extract_from_image
        image = params[:image]
        validation_error = validate_import_image(image)
        if validation_error
          return render json: { error: validation_error }, status: :unprocessable_entity
        end

        recipe = current_user.with_lock do
          check_import_limit_locked!
          current_user.recipes.create!(
            name: "Importing...",
            import_status: :pending
          )
        end

        recipe.import_image.attach(image)

        RecipeImageExtractJob.perform_later(current_user.id, recipe.id)

        render json: { id: recipe.id, import_status: recipe.import_status }, status: :accepted
      end

      private

      def recipe_list_json(recipe)
        {
          id: recipe.id,
          name: recipe.name,
          prep_time: recipe.prep_time,
          cook_time: recipe.cook_time,
          favorite: recipe.favorite,
          cover_image_url: cover_image_url(recipe, :thumbnail),
          import_status: recipe.import_status,
          error_message: recipe.error_message,
          updated_at: recipe.updated_at
        }
      end

      def recipe_detail_json(recipe)
        {
          id: recipe.id,
          name: recipe.name,
          prep_time: recipe.prep_time,
          cook_time: recipe.cook_time,
          servings: recipe.servings,
          favorite: recipe.favorite,
          ingredients: recipe.ingredients,
          instructions: recipe.instructions,
          notes: recipe.notes,
          source_url: recipe.source_url,
          tags: recipe.tags.map { |t| { id: t.id, name: t.name } },
          cover_image_url: cover_image_url(recipe, :display),
          created_at: recipe.created_at,
          updated_at: recipe.updated_at
        }
      end

      def cover_image_url(recipe, variant)
        return nil unless recipe.cover_image.attached?
        Rails.application.routes.url_helpers.rails_blob_path(
          recipe.cover_image.variant(variant),
          only_path: true
        )
      end

      def normalize_limit(raw_limit)
        limit = raw_limit.to_i
        limit = 100 if limit <= 0
        [ limit, 500 ].min
      end

      def encode_cursor(updated_at, id)
        payload = "#{updated_at.iso8601(6)}|#{id}"
        Base64.urlsafe_encode64(payload)
      end

      def decode_cursor(cursor)
        decoded = Base64.urlsafe_decode64(cursor.to_s)
        parts = decoded.split("|", 2)
        return nil unless parts.length == 2

        timestamp = Time.iso8601(parts[0])
        id = Integer(parts[1])
        [ timestamp, id ]
      rescue ArgumentError
        nil
      end

      def check_import_limit!
        return unless current_user.import_limit_reached?

        render_import_limit_reached
      end

      def render_import_limit_reached
        render json: {
          error: "Monthly import limit reached",
          error_code: "import_limit_reached",
          limit: User::FREE_MONTHLY_IMPORT_LIMIT
        }, status: :forbidden
      end

      def check_import_limit_locked!
        return unless current_user.import_limit_reached?

        raise ImportLimitReachedError
      end

      def validate_import_image(image)
        return "Image is required" if image.blank?
        unless image.respond_to?(:content_type) && image.respond_to?(:size)
          return "Invalid image upload"
        end
        return "Image must be an image" unless image.content_type.to_s.start_with?("image/")
        return "Image is too big (max 15MB)" if image.size > 15.megabytes

        nil
      end

      def track_failed_recipe_fetches(recipes)
        current_user.recipes
          .where(id: recipes.select(:id))
          .where(import_status: :failed, failed_recipe_fetched_at: nil)
          .update_all(failed_recipe_fetched_at: Time.current)
      end

      def cleanup_old_failed_recipes
        # TODO: Consider moving to a recurring background job if performance needs require it
        # Delete failed recipes that were fetched more than 1 minute ago
        current_user.recipes
          .where(import_status: :failed)
          .where("failed_recipe_fetched_at < ?", 1.minute.ago)
          .destroy_all
      end
    end
  end
end
