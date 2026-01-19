module Api
  module V1
    class RecipesController < BaseController
      def index
        recipes = current_user.recipes.with_attached_cover_image.includes(:tags)
        recipes = recipes.favorited if params[:favorites] == "true"
        recipes = recipes.order(updated_at: :desc)

        render json: recipes.map { |recipe| recipe_list_json(recipe) }
      end

      def show
        recipe = current_user.recipes.with_attached_cover_image.includes(:tags).find(params[:id])
        render json: recipe_detail_json(recipe)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Recipe not found" }, status: :not_found
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
        Rails.application.routes.url_helpers.rails_blob_url(
          recipe.cover_image.variant(variant),
          host: request.base_url
        )
      end
    end
  end
end
