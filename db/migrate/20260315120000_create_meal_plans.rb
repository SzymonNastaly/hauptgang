class CreateMealPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plans do |t|
      t.references :cookbook, null: false, foreign_key: { on_delete: :cascade }
      t.date :date, null: false
      t.timestamps
    end

    add_index :meal_plans, [ :cookbook_id, :date ], unique: true

    create_table :meal_plan_entries do |t|
      t.references :meal_plan, null: false, foreign_key: { on_delete: :cascade }
      t.references :recipe, null: false, foreign_key: { on_delete: :restrict }
      t.references :proposed_by_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end

    add_index :meal_plan_entries, [ :meal_plan_id, :recipe_id ], unique: true

    create_table :meal_plan_votes do |t|
      t.references :meal_plan_entry, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :meal_plan_votes, [ :meal_plan_entry_id, :user_id ], unique: true

    add_reference :meal_plans, :selected_entry, foreign_key: { to_table: :meal_plan_entries, on_delete: :nullify }
    add_reference :meal_plans, :selected_by_user, foreign_key: { to_table: :users, on_delete: :nullify }
    add_column :meal_plans, :selected_at, :datetime
  end
end
