class DropLegacyRecipeIngredients < ActiveRecord::Migration[8.1]
  def change
    drop_table :legacy_recipe_ingredients do |t|
      t.integer :recipe_id, null: false, index: true
      t.json :ingredients, default: []
    end
  end
end
