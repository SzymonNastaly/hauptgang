require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  setup do
    @recipe = recipes(:one)
  end

  test "is invalid without raw" do
    ingredient = Ingredient.new(recipe: @recipe, name: "flour")
    assert_not ingredient.valid?
    assert_includes ingredient.errors[:raw], "can't be blank"
  end

  test "is valid without name (parser fills it in later)" do
    ingredient = Ingredient.new(recipe: @recipe, raw: "1 cup flour")
    assert ingredient.valid?
  end

  test "is invalid without recipe" do
    ingredient = Ingredient.new(raw: "salt", name: "salt")
    assert_not ingredient.valid?
  end

  test "parsed? is true when amount present" do
    ingredient = Ingredient.new(raw: "1 cup flour", name: "flour", amount: 1)
    assert ingredient.parsed?
  end

  test "parsed? is true when unit present" do
    ingredient = Ingredient.new(raw: "a pinch of salt", name: "salt", unit: "pinch")
    assert ingredient.parsed?
  end

  test "parsed? is false when neither amount nor unit set" do
    ingredient = Ingredient.new(raw: "salt", name: "salt")
    assert_not ingredient.parsed?
  end
end
