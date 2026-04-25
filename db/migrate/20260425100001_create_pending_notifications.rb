class CreatePendingNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_notifications do |t|
      t.references :cookbook, null: false, foreign_key: { on_delete: :cascade }
      t.references :recipient, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :actor, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :category, null: false
      t.json :payload, null: false, default: []
      t.datetime :delivery_scheduled_at
      t.timestamps
    end

    add_index :pending_notifications,
              [ :cookbook_id, :recipient_id, :actor_id, :category ],
              unique: true,
              name: "index_pending_notifications_on_bucket"
  end
end
