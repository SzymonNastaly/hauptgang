require "json"
require "faraday"

module RecipeImporters
  # Extracts recipe data from Instagram reels using Apify.
  class InstagramReelExtractor
    Result = RecipeImporter::Result

    APIFY_ENDPOINT = "https://api.apify.com/v2/acts/apify~instagram-reel-scraper/run-sync-get-dataset-items"
    USER_AGENT = "Mozilla/5.0 (compatible; Hauptgang Instagram Importer)"

    def self.supports_url?(url)
      uri = URI.parse(url.to_s)
      host = uri.host.to_s.downcase
      return false unless host == "instagram.com" || host.end_with?(".instagram.com")

      path = uri.path.to_s
      path.include?("/reel/") || path.include?("/p/")
    rescue URI::InvalidURIError
      false
    end

    def initialize(url, http_client: nil)
      @url = url
      @http_client = http_client || build_http_client
    end

    def extract
      return failure("Please enter a URL", :blank_url) if @url.blank?

      token = apify_token
      return failure("Instagram import is not configured", :apify_missing_token) if token.blank?

      response = @http_client.post(APIFY_ENDPOINT) do |req|
        req.params["token"] = token
        req.headers["Content-Type"] = "application/json"
        req.body = build_payload.to_json
      end

      unless response.success?
        Rails.logger.info "[InstagramReelExtractor] HTTP #{response.status} for #{sanitized_url}"
        return failure("Could not fetch Instagram data", :apify_failed)
      end

      items = JSON.parse(response.body)
      unless items.is_a?(Array) && items.any?
        return failure("No Instagram data returned", :instagram_empty_result)
      end

      item = items.first
      caption = item["caption"].to_s.strip
      image_url = item["displayUrl"].to_s.strip.presence

      return failure("Instagram caption missing", :instagram_no_caption) if caption.blank?

      service_result = RecipeLlmService.new(caption, prompt_type: :raw_text, source_url: @url).extract
      return Result.new(
        success?: false,
        recipe_attributes: {},
        cover_image_url: image_url,
        error: service_result.error,
        error_code: service_result.error_code
      ) unless service_result.success?

      Result.new(
        success?: true,
        recipe_attributes: service_result.recipe_attributes,
        cover_image_url: image_url,
        error: nil,
        error_code: nil
      )
    rescue JSON::ParserError
      failure("Invalid Instagram response", :apify_invalid_response)
    rescue Faraday::TimeoutError
      failure("Instagram import timed out", :apify_timeout)
    rescue Faraday::ConnectionFailed
      failure("Could not connect to Instagram importer", :apify_connection_failed)
    rescue StandardError => e
      Rails.logger.error "[InstagramReelExtractor] Unexpected error for #{sanitized_url}: #{e.class} - #{e.message}"
      failure("Instagram import failed", :apify_failed)
    end

    private

    def build_payload
      {
        username: [ @url ],
        resultsLimit: 1
      }
    end

    def build_http_client
      Faraday.new do |f|
        f.options.timeout = 20
        f.options.open_timeout = 5
        f.headers["User-Agent"] = USER_AGENT
      end
    end

    def apify_token
      ENV["APIFY_API_KEY"] || Rails.application.credentials.dig(:apify, :api_key)
    end

    def sanitized_url
      URI.parse(@url).tap { |u| u.query = nil; u.fragment = nil }.to_s
    rescue URI::InvalidURIError
      "[invalid URL]"
    end

    def failure(message, code)
      Result.new(success?: false, recipe_attributes: {}, cover_image_url: nil, error: message, error_code: code)
    end
  end
end
