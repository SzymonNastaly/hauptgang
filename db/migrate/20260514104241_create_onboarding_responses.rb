class CreateOnboardingResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_responses do |t|
      t.string :device_id, null: false
      t.references :user, foreign_key: { on_delete: :cascade }
      t.json :answers, null: false, default: {}
      t.timestamps
    end

    add_index :onboarding_responses, :device_id, unique: true
  end
end
