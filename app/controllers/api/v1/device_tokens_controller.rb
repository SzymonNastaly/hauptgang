module Api
  module V1
    class DeviceTokensController < BaseController
      skip_before_action :set_current_cookbook!

      def create
        token = params[:token].to_s
        environment = params[:environment].to_s.presence || "production"

        unless DeviceToken::ENVIRONMENTS.include?(environment)
          return render json: { error: "Invalid environment" }, status: :unprocessable_entity
        end

        if token.blank?
          return render json: { error: "token is required" }, status: :unprocessable_entity
        end

        record = DeviceToken.register!(user: current_user, token: token, environment: environment)
        render json: { id: record.id, token: record.token, environment: record.environment }, status: :created
      end

      def destroy
        DeviceToken.where(user_id: current_user.id, token: params[:token]).destroy_all
        head :no_content
      end
    end
  end
end
