class AddErrorFieldsToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :error_message, :text
    add_column :recipes, :failed_recipe_fetched_at, :datetime
  end
end
