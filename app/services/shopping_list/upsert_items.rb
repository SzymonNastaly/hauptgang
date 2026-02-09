module ShoppingList
  class UpsertItems
    Result = Data.define(:success?, :items, :errors)

    def initialize(user:, items:)
      @user = user
      @items = items
    end

    def call
      return Result.new(success?: false, items: [], errors: [ empty_items_error ]) if @items.empty?

      created = []
      errors = []

      ActiveRecord::Base.transaction do
        @items.each do |item_params|
          client_id = item_params[:client_id]
          name = item_params[:name]

          if client_id.blank? || name.blank?
            errors << { client_id: client_id, error: "client_id and name are required" }
            next
          end

          source_recipe_id = resolve_source_recipe_id(item_params[:source_recipe_id])
          if item_params[:source_recipe_id].present? && source_recipe_id.nil?
            errors << { client_id: client_id, error: "Recipe not found" }
            next
          end

          item = upsert_item(client_id, name, source_recipe_id, item_params[:checked_at])
          if item.persisted? && item.errors.empty?
            created << item
          else
            errors << { client_id: client_id, error: item.errors.full_messages.to_sentence }
          end
        end

        if errors.any?
          raise ActiveRecord::Rollback
        end
      end

      if errors.any?
        Result.new(success?: false, items: [], errors: errors)
      else
        Result.new(success?: true, items: created, errors: [])
      end
    end

    private

    def upsert_item(client_id, name, source_recipe_id, checked_at)
      item = @user.shopping_list_items.find_or_initialize_by(client_id: client_id)
      item.name = name
      item.source_recipe_id = source_recipe_id
      item.checked_at = checked_at.presence
      item.save
      item
    rescue ActiveRecord::RecordNotUnique
      item = @user.shopping_list_items.find_by!(client_id: client_id)
      item.name = name
      item.source_recipe_id = source_recipe_id
      item.checked_at = checked_at.presence
      item.save
      item
    rescue ActiveRecord::InvalidForeignKey
      item = @user.shopping_list_items.find_or_initialize_by(client_id: client_id)
      item.name = name
      item.source_recipe_id = nil
      item.checked_at = checked_at.presence
      item.errors.add(:base, "Recipe not found")
      item
    end

    def resolve_source_recipe_id(source_recipe_id)
      return nil if source_recipe_id.blank?
      return source_recipe_id if @user.recipes.exists?(id: source_recipe_id)

      nil
    end

    def empty_items_error
      { client_id: nil, error: "No items provided" }
    end
  end
end
