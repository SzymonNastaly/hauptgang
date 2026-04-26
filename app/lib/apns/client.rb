require "apnotic"

module Apns
  # Thin wrapper around Apnotic providing one connection pool per environment
  # (production / sandbox). Reads credentials from Rails.application.credentials.apns:
  #   team_id, key_id, bundle_id, auth_key (PEM contents of the .p8)
  class Client
    Result = Data.define(:ok?, :status, :reason)

    class MissingCredentialsError < StandardError; end

    POOL_SIZE = 5

    class << self
      def push(token:, environment:, aps:, custom: {})
        notification = Apnotic::Notification.new(token)
        notification.alert = aps[:alert]
        notification.sound = aps[:sound] || "default"
        notification.badge = aps[:badge] if aps.key?(:badge)
        notification.topic = credentials.fetch(:bundle_id)
        notification.custom_payload = custom.transform_keys(&:to_s) if custom.any?

        connection_for(environment).with do |conn|
          response = conn.push(notification)
          if response.nil?
            Result.new(ok?: false, status: nil, reason: "timeout")
          elsif response.ok?
            Result.new(ok?: true, status: response.status, reason: nil)
          else
            body = response.body.is_a?(Hash) ? response.body : (JSON.parse(response.body) rescue {})
            Result.new(ok?: false, status: response.status, reason: body["reason"])
          end
        end
      end

      def reset!
        @pools&.each_value do |pool|
          pool.shutdown { |conn| conn.close rescue nil }
        end
        @pools = nil
      end

      private

      def connection_for(environment)
        @pools ||= {}
        @pools[environment.to_s] ||= build_pool(environment.to_s)
      end

      def build_pool(environment)
        creds = credentials
        connection_options = {
          auth_method: :token,
          cert_path: StringIO.new(creds.fetch(:auth_key)),
          key_id: creds.fetch(:key_id),
          team_id: creds.fetch(:team_id)
        }
        factory = environment == "sandbox" ? Apnotic::ConnectionPool.method(:development) : Apnotic::ConnectionPool.method(:new)
        factory.call(connection_options, size: POOL_SIZE) do |connection|
          connection.on(:error) do |exception|
            Rails.logger.error("APNs connection error: #{exception.class}: #{exception.message}")
          end
        end
      end

      def credentials
        creds = Rails.application.credentials.apns
        raise MissingCredentialsError, "Rails.application.credentials.apns is not configured" if creds.blank?
        creds.is_a?(Hash) ? creds : creds.to_h
      end
    end
  end
end
