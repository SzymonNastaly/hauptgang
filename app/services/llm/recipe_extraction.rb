module Llm
  module RecipeExtraction
    Result = Data.define(:success?, :recipe_attributes, :error, :error_code)

    private

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
end
