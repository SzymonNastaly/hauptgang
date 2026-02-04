require "nokogiri"

module RecipeImporters
  # Extracts recipe data from HTML using LLM when JSON-LD is not available.
  # Handles HTML preprocessing (cleaning) and delegates LLM extraction to RecipeLlmService.
  class LlmExtractor
    Result = RecipeImporter::Result

    REMOVABLE_TAGS = %w[script style nav header footer aside noscript iframe svg].freeze

    def initialize(html, source_url)
      @html = html
      @source_url = source_url
    end

    def extract
      cleaned_text = clean_html
      return extraction_failed("Could not extract text content from page") if cleaned_text.blank?

      service_result = RecipeLlmService.new(cleaned_text, prompt_type: :webpage, source_url: @source_url).extract
      convert_result(service_result)
    end

    private

    def clean_html
      doc = Nokogiri::HTML(@html)
      REMOVABLE_TAGS.each { |tag| doc.css(tag).remove }
      doc.text.gsub(/\s+/, " ").strip
    end

    def convert_result(service_result)
      Result.new(**service_result.to_h)
    end

    def extraction_failed(message)
      Result.new(success?: false, recipe_attributes: {}, error: message, error_code: :extraction_failed)
    end
  end
end
