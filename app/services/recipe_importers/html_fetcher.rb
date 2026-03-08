require "faraday"
require "faraday/follow_redirects"

module RecipeImporters
  class HtmlFetcher
    Result = Data.define(:success?, :body, :error, :error_code)

    MAX_RESPONSE_SIZE = 5.megabytes
    ALLOWED_CONTENT_TYPES = %w[text/html application/xhtml+xml].freeze

    def initialize(url, http_client:, log_prefix:)
      @url = url
      @http_client = http_client
      @log_prefix = log_prefix
    end

    def fetch
      response = @http_client.get(@url)

      unless response.success?
        Rails.logger.info "[#{@log_prefix}] HTTP #{response.status} for #{sanitized_url}"
        return failure("Could not fetch the page", :fetch_failed)
      end

      unless valid_content_type?(response)
        Rails.logger.info "[#{@log_prefix}] Invalid content-type for #{sanitized_url}: #{response.headers['content-type']}"
        return failure("The URL does not appear to be a web page", :invalid_content_type)
      end

      body = response.body
      body_size = body.bytesize

      if body_size > MAX_RESPONSE_SIZE
        Rails.logger.info "[#{@log_prefix}] Response too large for #{sanitized_url}: #{body_size} bytes"
        return failure("The page is too large to process", :response_too_large)
      end

      Result.new(success?: true, body: body, error: nil, error_code: nil)
    rescue Faraday::FollowRedirects::RedirectLimitReached
      Rails.logger.info "[#{@log_prefix}] Too many redirects for #{sanitized_url}"
      failure("Too many redirects", :too_many_redirects)
    rescue Faraday::TimeoutError
      Rails.logger.info "[#{@log_prefix}] Timeout for #{sanitized_url}"
      failure("The page took too long to load", :timeout)
    rescue Faraday::ConnectionFailed
      Rails.logger.info "[#{@log_prefix}] Connection failed for #{sanitized_url}"
      failure("Could not connect to the server", :connection_failed)
    rescue Faraday::Error, URI::InvalidURIError, Addressable::URI::InvalidURIError => error
      Rails.logger.info "[#{@log_prefix}] Fetch error for #{sanitized_url}: #{error.class}"
      failure("Could not fetch the page", :fetch_failed)
    end

    private

    def valid_content_type?(response)
      content_type = response.headers["content-type"].to_s.downcase
      ALLOWED_CONTENT_TYPES.any? { |allowed| content_type.start_with?(allowed) }
    end

    def sanitized_url
      URI.parse(@url).tap { |uri| uri.query = nil; uri.fragment = nil }.to_s
    rescue URI::InvalidURIError
      "[invalid URL]"
    end

    def failure(message, code)
      Result.new(success?: false, body: nil, error: message, error_code: code)
    end
  end
end
