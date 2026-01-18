module RecipeImporters
  # Placeholder for LLM-based recipe extraction
  # Will be implemented later to handle sites without JSON-LD
  class LlmExtractor
    Result = RecipeImporter::Result

    def initialize(html, source_url)
      @html = html
      @source_url = source_url
    end

    def extract
      # TODO: Implement LLM-based extraction
      # This would:
      # 1. Clean the HTML to extract main content
      # 2. Send to an LLM API with a prompt to extract recipe data
      # 3. Parse the LLM response into recipe attributes
      #
      # For now, just return failure to fall through to the error message
      Result.new(success?: false, recipe_attributes: {}, error: "LLM extraction not yet implemented", error_code: :not_implemented)
    end
  end
end
