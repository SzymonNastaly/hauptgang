module Api
  module V1
    class RecipesController < BaseController
      after_action :cleanup_old_failed_recipes, only: [ :index ]

      def index
        recipes = current_user.recipes.with_attached_cover_image.includes(:tags)
        recipes = recipes.favorited if params[:favorites] == "true"
        recipes = recipes.order(updated_at: :desc)

        # Track first fetch of failed recipes (before rendering)
        track_failed_recipe_fetches(recipes)

        render json: recipes.map { |recipe| recipe_list_json(recipe) }
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

        recipe = current_user.recipes.create!(
          name: "Importing...",
          source_url: url,
          import_status: :pending
        )

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

        recipe = current_user.recipes.create!(
          name: "Importing...",
          import_status: :pending
        )

        RecipeTextExtractJob.perform_later(current_user.id, recipe.id, text)

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
