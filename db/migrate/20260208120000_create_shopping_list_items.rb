class CreateShoppingListItems < ActiveRecord::Migration[8.1]
  def change
    create_table :shopping_list_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :client_id, null: false
      t.datetime :checked_at
      t.references :source_recipe, foreign_key: { to_table: :recipes }

      t.timestamps
    end

    add_index :shopping_list_items, [ :user_id, :client_id ], unique: true
    add_index :shopping_list_items, [ :user_id, :checked_at ]
  end
end
