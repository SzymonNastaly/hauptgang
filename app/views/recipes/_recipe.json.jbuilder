json.extract! recipe, :id, :name, :description, :instructions, :servings, :created_at, :updated_at
json.ingredients recipe.ingredients.map(&:raw)
json.structured_ingredients recipe.ingredients.map { |i|
  {
    id: i.id,
    position: i.position,
    amount: i.amount,
    amount_max: i.amount_max,
    unit: i.unit,
    name: i.name.presence || i.raw,
    note: i.note,
    raw: i.raw
  }
}
json.url recipe_url(recipe, format: :json)
