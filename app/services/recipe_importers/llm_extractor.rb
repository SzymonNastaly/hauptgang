require "nokogiri"
require "ruby_llm/schema"

module RecipeImporters
  # Extracts recipe data from HTML using LLM when JSON-LD is not available
  class LlmExtractor
    Result = RecipeImporter::Result

    # Schema for structured LLM output
    class RecipeSchema < RubyLLM::Schema
      string :name, description: "Recipe title"
      array :ingredients, of: :string, description: "List of ingredients with quantities"
      array :instructions, of: :string, description: "Step-by-step cooking instructions"
      integer :prep_time, required: false, description: "Preparation time in minutes"
      integer :cook_time, required: false, description: "Cooking time in minutes"
      integer :servings, required: false, description: "Number of servings"
      string :notes, required: false, description: "Recipe description or notes"
    end

    MAX_TEXT_LENGTH = 15_000
    REMOVABLE_TAGS = %w[script style nav header footer aside noscript iframe svg].freeze
    MODEL = "openai/gpt-oss-20b"

    def initialize(html, source_url)
      @html = html
      @source_url = source_url
    end

    def extract
      cleaned_text = clean_html
      return extraction_failed("Could not extract text content from page") if cleaned_text.blank?

      response = call_llm(cleaned_text)
      build_result(response.content)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      Result.new(success?: false, recipe_attributes: {}, error: "LLM request timed out: #{e.message}", error_code: :llm_timeout)
    rescue RubyLLM::Error => e
      Result.new(success?: false, recipe_attributes: {}, error: "LLM API error: #{e.message}", error_code: :llm_error)
    rescue StandardError => e
      Result.new(success?: false, recipe_attributes: {}, error: "Extraction failed: #{e.message}", error_code: :extraction_failed)
    end

    private

    def clean_html
      doc = Nokogiri::HTML(@html)

      # Remove non-content elements
      REMOVABLE_TAGS.each { |tag| doc.css(tag).remove }

      # Extract text and normalize whitespace
      text = doc.text.gsub(/\s+/, " ").strip
      text.truncate(MAX_TEXT_LENGTH)
    end

    def call_llm(text)
      chat = RubyLLM.chat(model: MODEL, provider: :openrouter)
      chat.with_schema(RecipeSchema).ask(prompt_for(text))
    end

    def prompt_for(text)
      <<~PROMPT
        Extract recipe information from the following webpage content.
        Find the recipe name, ingredients list, and cooking instructions.

        If you cannot find recipe content, return an empty name field.

        Webpage content:
        ---
        #{text}
        ---
      PROMPT
    end

    def build_result(content)
      return extraction_failed("No recipe data returned") if content.blank?

      name = content["name"].to_s.strip
      return extraction_failed("Could not identify recipe name") if name.blank?

      attributes = {
        name: name,
        ingredients: normalize_array(content["ingredients"]),
        instructions: normalize_array(content["instructions"]),
        prep_time: content["prep_time"],
        cook_time: content["cook_time"],
        servings: content["servings"],
        notes: content["notes"].to_s.strip.presence,
        source_url: @source_url
      }

      Result.new(success?: true, recipe_attributes: attributes, error: nil, error_code: nil)
    end

    def normalize_array(arr)
      return [] unless arr.is_a?(Array)
      arr.map { |item| item.to_s.strip }.reject(&:blank?)
    end

    def extraction_failed(message)
      Result.new(success?: false, recipe_attributes: {}, error: message, error_code: :extraction_failed)
    end
  end
end
