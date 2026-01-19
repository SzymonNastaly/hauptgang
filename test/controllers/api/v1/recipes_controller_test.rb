require "test_helper"

class Api::V1::RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    _token_record, @raw_token = ApiToken.generate_for(@user)
    @auth_headers = { "Authorization" => "Bearer #{@raw_token}" }
  end

  test "index returns user's recipes" do
    get api_v1_recipes_url, headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_kind_of Array, json
    # User one has 2 recipes (one and three)
    assert_equal 2, json.length
    recipe_names = json.map { |r| r["name"] }
    assert_includes recipe_names, "Pasta Carbonara"
    assert_includes recipe_names, "Caesar Salad"
  end

  test "index returns recipes ordered by updated_at desc" do
    get api_v1_recipes_url, headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    timestamps = json.map { |r| r["updated_at"] }
    assert_equal timestamps.sort.reverse, timestamps
  end

  test "index with favorites filter returns only favorites" do
    get api_v1_recipes_url, params: { favorites: "true" }, headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json.length
    assert_equal "Caesar Salad", json.first["name"]
    assert json.first["favorite"]
  end

  test "index returns expected fields" do
    get api_v1_recipes_url, headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    recipe = json.first
    assert recipe.key?("id")
    assert recipe.key?("name")
    assert recipe.key?("prep_time")
    assert recipe.key?("cook_time")
    assert recipe.key?("favorite")
    assert recipe.key?("cover_image_url")
    assert recipe.key?("updated_at")
  end

  test "index requires authentication" do
    get api_v1_recipes_url, as: :json

    assert_response :unauthorized
  end

  test "index returns 401 for expired token" do
    expired_headers = { "Authorization" => "Bearer test_token_expired" }

    get api_v1_recipes_url, headers: expired_headers, as: :json

    assert_response :unauthorized
  end

  test "index returns 401 for revoked token" do
    revoked_headers = { "Authorization" => "Bearer test_token_revoked" }

    get api_v1_recipes_url, headers: revoked_headers, as: :json

    assert_response :unauthorized
  end

  test "index does not return other user's recipes" do
    get api_v1_recipes_url, headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    recipe_names = json.map { |r| r["name"] }
    assert_not_includes recipe_names, "Chicken Curry"
  end

  test "show returns recipe details" do
    recipe = recipes(:one)

    get api_v1_recipe_url(recipe), headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal recipe.id, json["id"]
    assert_equal recipe.name, json["name"]
    assert_equal recipe.prep_time, json["prep_time"]
    assert_equal recipe.cook_time, json["cook_time"]
    assert_equal recipe.servings, json["servings"]
    assert_equal recipe.ingredients, json["ingredients"]
    assert_equal recipe.instructions, json["instructions"]
    assert json.key?("tags")
    assert json.key?("created_at")
    assert json.key?("updated_at")
  end

  test "show requires authentication" do
    recipe = recipes(:one)

    get api_v1_recipe_url(recipe), as: :json

    assert_response :unauthorized
  end

  test "show returns 404 for other user's recipe" do
    other_recipe = recipes(:two)

    get api_v1_recipe_url(other_recipe), headers: @auth_headers, as: :json

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Recipe not found", json["error"]
  end

  test "show returns 404 for nonexistent recipe" do
    get api_v1_recipe_url(id: 999999), headers: @auth_headers, as: :json

    assert_response :not_found
  end
end
