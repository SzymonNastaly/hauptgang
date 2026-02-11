module Api
  module V1
    class RegistrationsController < BaseController
      skip_before_action :authenticate_with_token!, only: :create
      unless Rails.env.local?
        rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
          render json: { error: "Too many signup attempts. Try again later." }, status: :too_many_requests
        }
      end

      def create
        user = User.new(
          email_address: params[:email],
          password: params[:password],
          password_confirmation: params[:password_confirmation]
        )

        if user.save
          token_record, raw_token = ApiToken.generate_for(user, name: params[:device_name])
          render json: {
            token: raw_token,
            expires_at: token_record.expires_at,
            user: { id: user.id, email: user.email_address }
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end
end
