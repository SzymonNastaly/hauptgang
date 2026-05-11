class BackfillRecipeIngredientsJob < ApplicationJob
  queue_as :default

  class LegacyRecipeIngredient < ApplicationRecord
    self.table_name = "legacy_recipe_ingredients"
  end

  def perform(recipe_id)
    recipe = Recipe.find_by(id: recipe_id)
    return unless recipe
    return if recipe.ingredients.any?

    legacy = LegacyRecipeIngredient.find_by(recipe_id: recipe_id)
    return unless legacy

    raw_lines = Array(legacy.ingredients).map { |s| s.to_s.strip }.reject(&:blank?)
    return if raw_lines.empty?

    Recipe.transaction do
      raw_lines.each_with_index do |raw, idx|
        recipe.ingredients.create!(position: idx, raw: raw, name: raw)
      end
    end

    ParseRecipeIngredientsJob.perform_later(recipe.id)
  end
end
