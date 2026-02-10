class AddProToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :pro, :boolean, default: false, null: false
    add_index :recipes, [ :user_id, :created_at ]
  end
end
