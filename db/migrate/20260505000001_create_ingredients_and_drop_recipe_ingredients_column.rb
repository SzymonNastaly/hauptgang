class CreateIngredientsAndDropRecipeIngredientsColumn < ActiveRecord::Migration[8.1]
  def up
    create_table :ingredients do |t|
      t.references :recipe, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.integer :position, null: false
      t.decimal :amount, precision: 10, scale: 4
      t.decimal :amount_max, precision: 10, scale: 4
      t.string :unit
      t.string :name, null: false
      t.string :note
      t.string :raw, null: false
      t.timestamps
    end

    create_table :legacy_recipe_ingredients do |t|
      t.integer :recipe_id, null: false, index: true
      t.json :ingredients, default: []
    end

    execute <<~SQL
      INSERT INTO legacy_recipe_ingredients (recipe_id, ingredients)
      SELECT id, ingredients FROM recipes
      WHERE ingredients IS NOT NULL AND ingredients != '[]'
    SQL

    remove_column :recipes, :ingredients
  end

  def down
    add_column :recipes, :ingredients, :json, default: []

    if table_exists?(:legacy_recipe_ingredients)
      execute <<~SQL
        UPDATE recipes SET ingredients = (
          SELECT ingredients FROM legacy_recipe_ingredients
          WHERE legacy_recipe_ingredients.recipe_id = recipes.id
        )
        WHERE id IN (SELECT recipe_id FROM legacy_recipe_ingredients)
      SQL
      drop_table :legacy_recipe_ingredients
    end

    drop_table :ingredients
  end
end
