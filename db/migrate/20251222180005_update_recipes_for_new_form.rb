class UpdateRecipesForNewForm < ActiveRecord::Migration[8.1]
  def change
    # Rename description to notes
    rename_column :recipes, :description, :notes

    # Add time fields
    add_column :recipes, :prep_time, :integer
    add_column :recipes, :cook_time, :integer

    # Convert ingredients and instructions to JSON
    # Note: SQLite supports JSON as of version 3.38.0
    change_column :recipes, :ingredients, :json, default: []
    change_column :recipes, :instructions, :json, default: []
  end
end
