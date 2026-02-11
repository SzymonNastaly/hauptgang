require "ruby_llm/schema"

# Extracts recipe data from an image using a vision-capable LLM.
class RecipeImageLlmService
  Result = Data.define(:success?, :recipe_attributes, :error, :error_code)

  MODEL = "meta-llama/llama-4-maverick"

  def initialize(image_path)
    @image_path = image_path
  end

  def extract
    return extraction_failed("No image provided") if @image_path.blank?

    response = call_llm
    build_result(response.content)
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    error_result("LLM request timed out: #{e.message}", :llm_timeout)
  rescue RubyLLM::Error => e
    error_result("LLM API error: #{e.message}", :llm_error)
  rescue StandardError => e
    error_result("Extraction failed: #{e.message}", :extraction_failed)
  end

  private

  def call_llm
    chat = RubyLLM.chat(model: MODEL, provider: :openrouter)
    chat.with_schema(Llm::RecipeSchema).ask(prompt, with: @image_path)
  end

  def prompt
    <<~PROMPT
      Extract recipe information from the image.
      Identify the recipe name, ingredients list, and cooking instructions.

      If the image does not contain a valid recipe, return an empty name field.
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
