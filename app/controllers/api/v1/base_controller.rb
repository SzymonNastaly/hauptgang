module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_with_token!

      private

      attr_reader :current_user, :current_api_token

      def authenticate_with_token!
        authenticate_with_http_token do |token, _options|
          @current_api_token = ApiToken.find_by_raw_token(token)
          if @current_api_token
            @current_api_token.touch_last_used!
            @current_user = @current_api_token.user
          end
        end

        render_unauthorized unless current_user
      end

      def render_unauthorized
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
