class AddUserToRecipes < ActiveRecord::Migration[8.1]
  def change
    # Step 1: Add column as nullable first (to handle existing recipes)
    add_reference :recipes, :user, null: true, foreign_key: true

    # Step 2: Assign existing recipes to the first user (if any exist)
    reversible do |dir|
      dir.up do
        first_user = User.first
        if first_user && Recipe.exists?
          Recipe.update_all(user_id: first_user.id)
        end
      end
    end

    # Step 3: Now make it non-nullable
    change_column_null :recipes, :user_id, false
  end
end
