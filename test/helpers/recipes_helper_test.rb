require "test_helper"

class RecipesHelperTest < ActionView::TestCase
  Ingredient = Struct.new(:amount, :amount_max, :unit, :name, :note, :raw, keyword_init: true)

  def ing(**attrs)
    Ingredient.new(amount: nil, amount_max: nil, unit: nil, name: "", note: nil, raw: "", **attrs)
  end

  test "format_quantity with amount and unit" do
    assert_equal "200 g", format_quantity(ing(amount: BigDecimal("200"), unit: "g"))
  end

  test "format_quantity strips trailing zeros" do
    assert_equal "200 g", format_quantity(ing(amount: BigDecimal("200.0"), unit: "g"))
    assert_equal "1.5 cups", format_quantity(ing(amount: BigDecimal("1.5"), unit: "cups"))
  end

  test "format_quantity uses unicode fractions for common values" do
    assert_equal "½ tsp", format_quantity(ing(amount: BigDecimal("0.5"), unit: "tsp"))
    assert_equal "¼ cup", format_quantity(ing(amount: BigDecimal("0.25"), unit: "cup"))
    assert_equal "⅓", format_quantity(ing(amount: BigDecimal("0.3333")))
  end

  test "format_quantity with range scales both bounds" do
    assert_equal "200\u2013250 g", format_quantity(ing(amount: BigDecimal("200"), amount_max: BigDecimal("250"), unit: "g"))
  end

  test "format_quantity with no amount returns just unit" do
    assert_equal "pinch", format_quantity(ing(unit: "pinch"))
  end

  test "format_quantity with neither amount nor unit returns blank" do
    assert_equal "", format_quantity(ing)
  end

  test "format_amount handles BigDecimal values" do
    assert_equal "200", format_amount(BigDecimal("200.0"))
    assert_equal "½", format_amount(BigDecimal("0.5000"))
    assert_equal "0.06", format_amount(BigDecimal("0.0625"))
  end
end
