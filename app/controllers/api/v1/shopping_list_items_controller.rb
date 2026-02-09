module Api
  module V1
    class ShoppingListItemsController < BaseController
      before_action :cleanup_stale_checked_items, only: [ :index ]

      def index
        unchecked = current_user.shopping_list_items.unchecked.order(created_at: :desc)
        checked = current_user.shopping_list_items.checked.order(checked_at: :asc)
        items = unchecked + checked

        render json: items.map { |item| ShoppingListItemSerializer.new(item).as_json }
      end

      def create
        payload_items = ShoppingList::Payload.normalize(params)
        result = ShoppingList::UpsertItems.new(user: current_user, items: payload_items).call

        unless result.success?
          first_error = result.errors.first
          return render json: { error: first_error[:error], errors: result.errors }, status: :unprocessable_entity
        end

        render json: result.items.map { |item| ShoppingListItemSerializer.new(item).as_json }, status: :created
      end

      def update
        item = current_user.shopping_list_items.find(params[:id])

        if params.key?(:checked_at)
          if params[:checked_at].blank?
            item.checked_at = nil
          else
            item.checked_at = Time.iso8601(params[:checked_at])
          end
        elsif params.key?(:checked)
          checked = ActiveModel::Type::Boolean.new.cast(params[:checked])
          item.checked_at = checked ? Time.current : nil
        else
          return render json: { error: "checked or checked_at is required" }, status: :unprocessable_entity
        end

        item.save!
        render json: ShoppingListItemSerializer.new(item).as_json
      rescue ArgumentError
        render json: { error: "Invalid checked_at format" }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Shopping list item not found" }, status: :not_found
      rescue ActiveRecord::RecordInvalid
        render json: { error: "Could not update item" }, status: :unprocessable_entity
      end

      def destroy
        item = current_user.shopping_list_items.find(params[:id])
        item.destroy!
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Shopping list item not found" }, status: :not_found
      rescue ActiveRecord::RecordNotDestroyed
        render json: { error: "Could not delete item" }, status: :unprocessable_entity
      end

      private

      def cleanup_stale_checked_items
        ShoppingListItem.cleanup_stale_checked_for(current_user)
      end
    end
  end
end
