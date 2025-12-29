class RecipesController < ApplicationController
  before_action :set_recipe, only: %i[ show edit update destroy toggle_favorite ]

  # GET /recipes or /recipes.json
  def index
    @recipes = Current.user.recipes

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

  # GET /recipes/new
  def new
    @recipe = Current.user.recipes.build
  end

  # GET /recipes/1/edit
  def edit
  end

  # POST /recipes or /recipes.json
  def create
    @recipe = Current.user.recipes.build(recipe_params)

    respond_to do |format|
      if @recipe.save
        flash[:invalidate_cache] = recipe_path(@recipe)
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
    respond_to do |format|
      if @recipe.update(recipe_params)
        flash[:invalidate_cache] = recipe_path(@recipe)
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
    recipe_path_for_cache = recipe_path(@recipe)
    @recipe.destroy!
    flash[:invalidate_cache] = recipe_path_for_cache

    respond_to do |format|
      format.html { redirect_to recipes_path, notice: "Recipe was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # PATCH /recipes/1/toggle_favorite
  def toggle_favorite
    @recipe.update(favorite: !@recipe.favorite)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to recipes_path }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    # Scoped to current user - prevents accessing other users' recipes
    def set_recipe
      @recipe = Current.user.recipes.find(params.expect(:id))
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

      # Filter out empty strings from arrays
      if permitted[:ingredients].is_a?(Array)
        permitted[:ingredients] = permitted[:ingredients].reject(&:blank?)
      end

      if permitted[:instructions].is_a?(Array)
        permitted[:instructions] = permitted[:instructions].reject(&:blank?)
      end

      permitted
    end
end
