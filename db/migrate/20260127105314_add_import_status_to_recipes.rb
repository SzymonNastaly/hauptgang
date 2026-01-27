class AddImportStatusToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :import_status, :integer, default: 1, null: false
  end
end
