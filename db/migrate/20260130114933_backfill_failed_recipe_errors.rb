class BackfillFailedRecipeErrors < ActiveRecord::Migration[8.1]
  def up
    # Delete existing failed recipes for a clean slate
    # These recipes are stuck in a bad state without error messages
    Recipe.where(import_status: :failed).destroy_all
  end

  def down
    # No-op: Can't restore deleted recipes
  end
end
