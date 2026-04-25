class CreateDeviceTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :device_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token, null: false
      t.string :environment, null: false, default: "production"
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :device_tokens, :token, unique: true
  end
end
