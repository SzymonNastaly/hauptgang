class CreateCookbooks < ActiveRecord::Migration[8.1]
  def change
    create_table :cookbooks do |t|
      t.string :name, null: false
      t.boolean :personal, default: false, null: false

      t.timestamps
    end

    create_table :cookbook_memberships do |t|
      t.references :cookbook, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    add_index :cookbook_memberships, [ :cookbook_id, :user_id ], unique: true

    create_table :cookbook_invitations do |t|
      t.references :cookbook, null: false, foreign_key: { on_delete: :cascade }
      t.references :inviter, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :token, null: false
      t.integer :status, default: 0, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :cookbook_invitations, :token, unique: true
  end
end
