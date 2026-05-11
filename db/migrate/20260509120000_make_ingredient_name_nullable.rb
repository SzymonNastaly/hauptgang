class MakeIngredientNameNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :ingredients, :name, true
  end
end
