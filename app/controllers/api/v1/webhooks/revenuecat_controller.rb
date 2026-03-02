module Api
  module V1
    module Webhooks
      class RevenuecatController < BaseController
        before_action :verify_authorization

        def create
          app_user_id = params.dig(:event, :app_user_id)
          user = User.find_by(id: app_user_id)

          # Return 200 for unknown users to stop RevenueCat retries
          unless user
            head :ok
            return
          end

          pro = entitlement_active?
          user.update!(pro: pro)

          head :ok
        end

        private

        def verify_authorization
          expected = webhook_secret
          return if expected.blank?

          provided = request.headers["Authorization"].to_s
          unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)
            head :unauthorized
          end
        end

        def webhook_secret
          ENV["REVENUECAT_WEBHOOK_SECRET"] || Rails.application.credentials.dig(:revenuecat, :webhook_secret)
        end

        def entitlement_active?
          entitlement_ids = params.dig(:event, :entitlement_ids) || []
          return false unless entitlement_ids.include?("Hauptgang Pro")

          expiration_ms = params.dig(:event, :expiration_at_ms)
          return true if expiration_ms.blank? # Lifetime entitlement

          Time.at(expiration_ms / 1000.0) > Time.current
        end
      end
    end
  end
end
