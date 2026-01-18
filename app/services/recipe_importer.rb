require "faraday"
require "faraday/follow_redirects"

# Imports a recipe from a URL by extracting structured data
# Tries JSON-LD first, then falls back to LLM extraction
class RecipeImporter
  Result = Data.define(:success?, :recipe_attributes, :error, :error_code)

  MAX_RESPONSE_SIZE = 5.megabytes
  MAX_REDIRECTS = 5
  ALLOWED_CONTENT_TYPES = %w[text/html application/xhtml+xml].freeze

  def initialize(url, http_client: nil)
    @url = url
    @http_client = http_client || build_http_client
  end

  def import
    return failure("Please enter a URL", :blank_url) if @url.blank?

    validation = RecipeImporters::UrlValidator.new(@url).validate
    return failure(validation.error, :invalid_url) unless validation.success?

    fetch_result = fetch_html
    return failure(fetch_result[:error], fetch_result[:error_code]) unless fetch_result[:success]

    html = fetch_result[:body]

    # Try JSON-LD extraction first (most recipe sites use this)
    result = RecipeImporters::JsonLdExtractor.new(html, @url).extract
    return result if result.success?

    # Fall back to LLM extraction (placeholder for now)
    result = RecipeImporters::LlmExtractor.new(html, @url).extract
    return result if result.success?

    # Nothing worked
    failure("Could not extract recipe from this page. The site may not have structured recipe data.", :no_recipe_found)
  end

  private

  def fetch_html
    response = @http_client.get(@url)

    unless response.success?
      Rails.logger.info "[RecipeImporter] HTTP #{response.status} for #{sanitized_url}"
      return { success: false, error: "Could not fetch the page", error_code: :fetch_failed }
    end

    unless valid_content_type?(response)
      Rails.logger.info "[RecipeImporter] Invalid content-type for #{sanitized_url}: #{response.headers['content-type']}"
      return { success: false, error: "The URL does not appear to be a web page", error_code: :invalid_content_type }
    end

    if response.body.bytesize > MAX_RESPONSE_SIZE
      Rails.logger.info "[RecipeImporter] Response too large for #{sanitized_url}: #{response.body.bytesize} bytes"
      return { success: false, error: "The page is too large to process", error_code: :response_too_large }
    end

    { success: true, body: response.body }
  rescue Faraday::FollowRedirects::RedirectLimitReached
    Rails.logger.info "[RecipeImporter] Too many redirects for #{sanitized_url}"
    { success: false, error: "Too many redirects", error_code: :too_many_redirects }
  rescue Faraday::TimeoutError
    Rails.logger.info "[RecipeImporter] Timeout for #{sanitized_url}"
    { success: false, error: "The page took too long to load", error_code: :timeout }
  rescue Faraday::ConnectionFailed
    Rails.logger.info "[RecipeImporter] Connection failed for #{sanitized_url}"
    { success: false, error: "Could not connect to the server", error_code: :connection_failed }
  rescue Faraday::Error, URI::InvalidURIError, Addressable::URI::InvalidURIError => e
    Rails.logger.info "[RecipeImporter] Fetch error for #{sanitized_url}: #{e.class}"
    { success: false, error: "Could not fetch the page", error_code: :fetch_failed }
  end

  def build_http_client
    Faraday.new do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
      f.headers["User-Agent"] = "Mozilla/5.0 (compatible; Hauptgang Recipe Importer)"
      f.headers["Accept"] = "text/html"
      f.response :follow_redirects, limit: MAX_REDIRECTS
    end
  end

  def valid_content_type?(response)
    content_type = response.headers["content-type"].to_s.downcase
    ALLOWED_CONTENT_TYPES.any? { |allowed| content_type.start_with?(allowed) }
  end

  def sanitized_url
    URI.parse(@url).tap { |u| u.query = nil; u.fragment = nil }.to_s
  rescue URI::InvalidURIError
    "[invalid URL]"
  end

  def failure(message, code)
    Result.new(success?: false, recipe_attributes: {}, error: message, error_code: code)
  end
end
