class EnforceCookbookConstraints < ActiveRecord::Migration[8.1]
  def change
    # Make cookbook_id NOT NULL now that all rows are backfilled
    change_column_null :recipes, :cookbook_id, false
    change_column_null :shopping_list_items, :cookbook_id, false

    # Make user_id nullable on recipes and shopping_list_items (ON DELETE SET NULL)
    change_column_null :recipes, :user_id, true
    change_column_null :shopping_list_items, :user_id, true

    # Replace shopping_list_items unique index: (user_id, client_id) → (cookbook_id, client_id)
    remove_index :shopping_list_items, [ :user_id, :client_id ]
    add_index :shopping_list_items, [ :cookbook_id, :client_id ], unique: true

    # Add composite index for batch endpoint (orders by updated_at, id with cursor predicate)
    add_index :recipes, [ :cookbook_id, :updated_at, :id ]

    # Replace existing FK constraints with ON DELETE SET NULL for user_id columns
    remove_foreign_key :recipes, :users
    add_foreign_key :recipes, :users, on_delete: :nullify

    remove_foreign_key :shopping_list_items, :users
    add_foreign_key :shopping_list_items, :users, on_delete: :nullify

    # Add ON DELETE CASCADE to recipe_tags.recipe_id (needed for cookbook cascade deletion)
    remove_foreign_key :recipe_tags, :recipes
    add_foreign_key :recipe_tags, :recipes, on_delete: :cascade

    # Ensure shopping_list_items.source_recipe_id has ON DELETE SET NULL
    remove_foreign_key :shopping_list_items, column: :source_recipe_id
    add_foreign_key :shopping_list_items, :recipes, column: :source_recipe_id, on_delete: :nullify
  end
end
