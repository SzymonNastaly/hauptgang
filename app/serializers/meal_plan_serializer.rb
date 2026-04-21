class MealPlanSerializer
  def initialize(meal_plan, current_user:)
    @meal_plan = meal_plan
    @current_user = current_user
  end

  def as_json(*)
    {
      date: @meal_plan.date.iso8601,
      selected_entry_id: @meal_plan.selected_entry_id,
      selected_by_user_id: @meal_plan.selected_by_user_id,
      selected_at: @meal_plan.selected_at,
      entries: @meal_plan.entries.map { |entry| entry_json(entry) }
    }
  end

  private

  def entry_json(entry)
    {
      id: entry.id,
      recipe: recipe_json(entry.recipe),
      proposed_by: user_json(entry.proposed_by_user),
      vote_count: entry.votes.size,
      voted_by_current_user: entry.votes.any? { |v| v.user_id == @current_user.id }
    }
  end

  def recipe_json(recipe)
    {
      id: recipe.id,
      name: recipe.name,
      # TODO: Remove legacy cover_image_url once older iOS builds have migrated
      # to the structured cover_images payload.
      cover_image_url: recipe.cover_image_variant_url(:thumb),
      cover_images: recipe.cover_image_urls
    }
  end

  def user_json(user)
    return nil unless user
    { id: user.id, email: user.email_address }
  end
end
