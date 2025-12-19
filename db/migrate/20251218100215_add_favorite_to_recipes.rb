class AddFavoriteToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :favorite, :boolean, default: false
  end
end
