class AddDetailsToShoppingListItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shopping_list_items, :details, :string
  end
end
