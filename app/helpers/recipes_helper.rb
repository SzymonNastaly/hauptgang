module RecipesHelper
  # Format an Ingredient's quantity for display.
  #
  # Examples:
  #   amount=200, unit="g"            => "200 g"
  #   amount=0.5, unit="tsp"          => "½ tsp"
  #   amount=2, amount_max=3          => "2–3"
  #   amount=200, amount_max=250, "g" => "200–250 g"
  #   amount=nil,  unit="pinch"       => "pinch"
  #   amount=nil,  unit=nil           => ""
  def format_quantity(ingredient)
    amount = ingredient.amount
    amount_max = ingredient.amount_max
    unit = ingredient.unit.presence

    quantity =
      if amount.present? && amount_max.present?
        "#{format_amount(amount)}\u2013#{format_amount(amount_max)}"
      elsif amount.present?
        format_amount(amount)
      else
        nil
      end

    [ quantity, unit ].compact.join(" ")
  end

  # Format an amount for scaled display, given a numeric value.
  # Used by the portion scaler controller for the initial render parity check
  # and is the canonical formatter for client-side scaling output.
  def format_amount(value)
    return "" if value.nil?

    decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)

    if (fraction = unicode_fraction(decimal))
      return fraction
    end

    rounded = decimal.round(2)
    string = rounded.to_s("F")
    string.sub(/\.?0+\z/, "")
  end

  UNICODE_FRACTIONS = {
    BigDecimal("0.25")    => "\u00BC",
    BigDecimal("0.5")     => "\u00BD",
    BigDecimal("0.75")    => "\u00BE",
    BigDecimal("0.3333")  => "\u2153",
    BigDecimal("0.6667")  => "\u2154",
    BigDecimal("0.125")   => "\u215B",
    BigDecimal("0.375")   => "\u215C",
    BigDecimal("0.625")   => "\u215D",
    BigDecimal("0.875")   => "\u215E"
  }.freeze

  def unicode_fraction(decimal)
    UNICODE_FRACTIONS.each do |key, glyph|
      return glyph if (decimal - key).abs < BigDecimal("0.005")
    end
    nil
  end
end
