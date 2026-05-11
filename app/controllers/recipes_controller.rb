class RecipesController < ApplicationController
  before_action :set_recipe, only: %i[ show edit update destroy toggle_favorite ]

  # GET /recipes or /recipes.json
  def index
    @recipes = personal_cookbook.recipes
      .with_attached_cover_image
      .includes(:tags)

    # Filter by favorites if requested
    @recipes = @recipes.favorited if params[:view] == "favorites"

    # Filter by tag if requested
    if params[:tag].present?
      @selected_tag = Tag.find_by(slug: params[:tag])
      @recipes = @recipes.joins(:tags).where(tags: { id: @selected_tag.id }) if @selected_tag
    end

    @tags = Tag.all.order(:name)

    # Set ETag for conditional requests (304 Not Modified)
    fresh_when(@recipes)
  end

  # GET /recipes/1 or /recipes/1.json
  def show
    # Set ETag for conditional requests (304 Not Modified)
    fresh_when(@recipe)
  end

  # GET /recipes/new - Choice screen
  def new
  end

  # GET /recipes/new/form - Manual recipe creation form
  def new_form
    attrs = imported_recipe_params
    raw_lines = attrs.delete(:imported_ingredient_strings) || []
    @recipe = personal_cookbook.recipes.build(attrs.merge(user: Current.user))
    raw_lines.each_with_index do |raw, idx|
      @recipe.ingredients.build(position: idx, raw: raw)
    end
  end

  # GET /recipes/new/import - Import URL input
  def new_import
  end

  # POST /recipes/import - Process URL and redirect to form
  def import
    result = RecipeImporter.new(params[:url]).import

    if result.success?
      session[:imported_recipe] = result.recipe_attributes
      redirect_to new_form_recipes_path
    else
      flash.now[:alert] = result.error
      render :new_import, status: :unprocessable_entity
    end
  end

  # GET /recipes/1/edit
  def edit
  end

  # POST /recipes or /recipes.json
  def create
    attrs = recipe_params
    ingredients_strings = attrs.delete(:ingredients)
    @recipe = personal_cookbook.recipes.build(attrs.merge(user: Current.user))

    respond_to do |format|
      if @recipe.save
        @recipe.replace_ingredients_from_strings(ingredients_strings) if ingredients_strings
        enqueue_parse_job(@recipe)
        format.html { redirect_to @recipe, notice: "Recipe was successfully created." }
        format.json { render :show, status: :created, location: @recipe }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @recipe.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /recipes/1 or /recipes/1.json
  def update
    attrs = recipe_params
    ingredients_strings = attrs.delete(:ingredients)

    respond_to do |format|
      if @recipe.update(attrs)
        @recipe.replace_ingredients_from_strings(ingredients_strings) if ingredients_strings
        enqueue_parse_job(@recipe)
        format.html { redirect_to @recipe, notice: "Recipe was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @recipe }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @recipe.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /recipes/1 or /recipes/1.json
  def destroy
    @recipe.destroy!

    respond_to do |format|
      format.html { redirect_to recipes_path, notice: "Recipe was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  rescue ActiveRecord::RecordNotDestroyed => e
    alert = e.record.errors.full_messages.to_sentence.presence || "Could not delete recipe."
    respond_to do |format|
      format.html { redirect_to recipes_path, alert: alert, status: :see_other }
      format.json { render json: { error: alert }, status: :unprocessable_entity }
    end
  end

  # PATCH /recipes/1/toggle_favorite
  def toggle_favorite
    @recipe.update(favorite: !@recipe.favorite)
    @context = request.referer&.include?(recipe_path(@recipe)) ? :show : :card

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to recipes_path }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    # Scoped to current user - prevents accessing other users' recipes
    def set_recipe
      @recipe = personal_cookbook.recipes.find(params.expect(:id))
    end

    def personal_cookbook
      @personal_cookbook ||= Current.user.personal_cookbook
    end

    # Params for imported recipe (from session storage). Returns a hash usable
    # with Recipe.new — `imported_ingredients` is consumed separately by the form.
    def imported_recipe_params
      imported = session.delete(:imported_recipe)
      return {} unless imported.present?

      attrs = imported.slice(
        "name",
        "notes",
        "servings",
        "prep_time",
        "cook_time",
        "source_url",
        "instructions"
      ).symbolize_keys

      raw_lines = Array(imported["ingredients"]).map do |ing|
        ing.is_a?(Hash) ? ing["raw"].presence || ing["name"].to_s : ing.to_s
      end.reject(&:blank?)

      attrs[:imported_ingredient_strings] = raw_lines if raw_lines.any?
      attrs
    end

    # Only allow a list of trusted parameters through.
    def recipe_params
      permitted = params.require(:recipe).permit(
        :name,
        :notes,
        :servings,
        :prep_time,
        :cook_time,
        :cover_image,
        tag_ids: [],
        ingredients: [],
        instructions: []
      )

      if permitted[:instructions].is_a?(Array)
        permitted[:instructions] = permitted[:instructions].reject(&:blank?)
      end

      if permitted[:ingredients].is_a?(Array)
        permitted[:ingredients] = permitted[:ingredients].reject(&:blank?)
      end

      permitted
    end

    def enqueue_parse_job(recipe)
      return unless recipe.ingredients.any? { |i| !i.parsed? }
      ParseRecipeIngredientsJob.perform_later(recipe.id)
    end
end
