require "ruby_llm/schema"

module Llm
  class RecipeSchema < RubyLLM::Schema
    string :name, description: "Recipe title"
    array :ingredients, of: :string, description: "List of ingredients with quantities"
    array :instructions, of: :string, description: "Step-by-step cooking instructions"
    integer :prep_time, required: false, description: "Preparation time in minutes"
    integer :cook_time, required: false, description: "Cooking time in minutes"
    integer :servings, required: false, description: "Number of servings"
    string :notes, required: false, description: "Recipe description or notes"
  end
end
