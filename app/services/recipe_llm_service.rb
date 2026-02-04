require "ruby_llm/schema"

# Extracts recipe data from text using an LLM.
# Supports extraction from webpage content or raw recipe text.
class RecipeLlmService
  Result = Data.define(:success?, :recipe_attributes, :error, :error_code)

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
  MODEL = "openai/gpt-oss-20b"
  PROMPT_TYPES = %i[webpage raw_text].freeze

  def initialize(text, prompt_type: :webpage, source_url: nil)
    raise ArgumentError, "Invalid prompt_type: #{prompt_type}" unless PROMPT_TYPES.include?(prompt_type)

    @text = text
    @prompt_type = prompt_type
    @source_url = source_url
  end

  def extract
    truncated_text = @text.to_s[0, MAX_TEXT_LENGTH]
    return extraction_failed("No text content provided") if truncated_text.blank?

    response = call_llm(truncated_text)
    build_result(response.content)
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    error_result("LLM request timed out: #{e.message}", :llm_timeout)
  rescue RubyLLM::Error => e
    error_result("LLM API error: #{e.message}", :llm_error)
  rescue StandardError => e
    error_result("Extraction failed: #{e.message}", :extraction_failed)
  end

  private

  def call_llm(text)
    chat = RubyLLM.chat(model: MODEL, provider: :openrouter)
    chat.with_schema(RecipeSchema).ask(prompt_for(text))
  end

  def prompt_for(text)
    case @prompt_type
    when :webpage
      webpage_prompt(text)
    when :raw_text
      raw_text_prompt(text)
    end
  end

  def webpage_prompt(text)
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

  def raw_text_prompt(text)
    <<~PROMPT
      Extract recipe information from the following text.
      Parse the recipe name, ingredients list, and cooking instructions.

      If the text does not contain a valid recipe, return an empty name field.

      Recipe text:
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
      notes: content["notes"].to_s.strip.presence
    }
    attributes[:source_url] = @source_url if @source_url.present?

    Result.new(success?: true, recipe_attributes: attributes, error: nil, error_code: nil)
  end

  def normalize_array(arr)
    return [] unless arr.is_a?(Array)
    arr.map { |item| item.to_s.strip }.reject(&:blank?)
  end

  def extraction_failed(message)
    error_result(message, :extraction_failed)
  end

  def error_result(message, code)
    Result.new(success?: false, recipe_attributes: {}, error: message, error_code: code)
  end
end
