class AddCookbookIdToRecipesAndShoppingListItems < ActiveRecord::Migration[8.1]
  def change
    # Add nullable cookbook_id first (will be made NOT NULL after data migration)
    add_reference :recipes, :cookbook, null: true, foreign_key: { on_delete: :cascade }
    add_reference :shopping_list_items, :cookbook, null: true, foreign_key: { on_delete: :cascade }
  end
end
