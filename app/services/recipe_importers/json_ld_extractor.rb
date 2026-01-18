require "nokogiri"
require "json"

module RecipeImporters
  # Extracts recipe data from JSON-LD structured data (schema.org/Recipe)
  # Most recipe websites include this for SEO purposes
  class JsonLdExtractor
    Result = RecipeImporter::Result

    def initialize(html, source_url)
      @html = html
      @source_url = source_url
    end

    def extract
      doc = Nokogiri::HTML(@html)

      # Find all JSON-LD scripts
      json_ld_scripts = doc.css('script[type="application/ld+json"]')

      json_ld_scripts.each do |script|
        data = parse_json(script.text)
        next unless data

        recipe = find_recipe(data)
        next unless recipe

        attributes = extract_attributes(recipe)
        return Result.new(success?: true, recipe_attributes: attributes, error: nil, error_code: nil) if attributes[:name].present?
      end

      Result.new(success?: false, recipe_attributes: {}, error: "No JSON-LD recipe data found", error_code: :no_json_ld)
    end

    private

    def parse_json(text)
      JSON.parse(text)
    rescue JSON::ParserError
      nil
    end

    def find_recipe(data)
      # Handle array of items
      if data.is_a?(Array)
        data.each do |item|
          recipe = find_recipe(item)
          return recipe if recipe
        end
        return nil
      end

      return nil unless data.is_a?(Hash)

      # Check if this is a Recipe
      if recipe_type?(data)
        return data
      end

      # Check mainEntity/mainEntityOfPage wrappers (e.g., WebPage wrapping Recipe)
      %w[mainEntity mainEntityOfPage].each do |key|
        if data[key].is_a?(Hash)
          recipe = find_recipe(data[key])
          return recipe if recipe
        end
      end

      # Check @graph for Recipe
      if data["@graph"].is_a?(Array)
        data["@graph"].each do |item|
          recipe = find_recipe(item)
          return recipe if recipe
        end
      end

      nil
    end

    def recipe_type?(data)
      type = data["@type"]
      return false unless type

      types = type.is_a?(Array) ? type : [ type ]
      types.any? { |t| t == "Recipe" || t.to_s.match?(%r{\Ahttps?://schema\.org/Recipe\z}) }
    end

    def extract_attributes(recipe)
      {
        name: extract_name(recipe),
        ingredients: extract_ingredients(recipe),
        instructions: extract_instructions(recipe),
        prep_time: extract_duration(recipe["prepTime"]),
        cook_time: extract_duration(recipe["cookTime"]),
        servings: extract_servings(recipe),
        notes: extract_notes(recipe),
        source_url: @source_url
      }
    end

    def extract_name(recipe)
      recipe["name"].to_s.strip.presence
    end

    def extract_ingredients(recipe)
      ingredients = recipe["recipeIngredient"] || recipe["ingredients"] || []
      ingredients = [ ingredients ] unless ingredients.is_a?(Array)
      ingredients.map { |i| i.to_s.strip }.reject(&:blank?)
    end

    def extract_instructions(recipe)
      instructions = recipe["recipeInstructions"] || []

      # Handle ItemList wrapper
      if instructions.is_a?(Hash) && instructions["@type"] == "ItemList"
        instructions = instructions["itemListElement"] || []
      end

      instructions = [ instructions ] unless instructions.is_a?(Array)

      instructions.flat_map do |instruction|
        case instruction
        when String
          instruction.strip
        when Hash
          # HowToStep or HowToSection
          if instruction["@type"] == "HowToSection"
            extract_section_steps(instruction)
          elsif instruction["@type"] == "ListItem"
            extract_list_item_text(instruction)
          else
            instruction["text"].to_s.strip
          end
        else
          nil
        end
      end.compact.reject(&:blank?)
    end

    def extract_list_item_text(list_item)
      item = list_item["item"]
      case item
      when String
        item.strip
      when Hash
        item["text"].to_s.strip
      else
        list_item["name"].to_s.strip
      end
    end

    def extract_section_steps(section)
      steps = section["itemListElement"] || []
      steps.map do |step|
        step.is_a?(Hash) ? step["text"].to_s.strip : step.to_s.strip
      end
    end

    def extract_duration(iso_duration)
      return nil unless iso_duration.present?

      duration_str = iso_duration.to_s

      # Parse full ISO 8601 duration (e.g., "PT30M", "PT1H30M", "P1D", "P1DT2H30M", "PT45S")
      match = duration_str.match(/P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?/)
      return nil unless match

      days = match[1].to_i
      hours = match[2].to_i
      minutes = match[3].to_i
      seconds = match[4].to_i

      total_minutes = (days * 1440) + (hours * 60) + minutes
      total_minutes += 1 if seconds.positive? && (total_minutes.zero? || seconds >= 30)

      total_minutes.positive? ? total_minutes : nil
    end

    def extract_servings(recipe)
      yield_value = recipe["recipeYield"]
      return nil unless yield_value.present?

      # Handle array (take first)
      yield_value = yield_value.first if yield_value.is_a?(Array)

      # Try to extract number
      match = yield_value.to_s.match(/\d+/)
      match ? match[0].to_i : nil
    end

    def extract_notes(recipe)
      # Some recipes have notes in description
      description = recipe["description"].to_s.strip
      description.presence
    end
  end
end
