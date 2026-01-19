require "test_helper"

class Api::V1::FavoritesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    _token_record, @raw_token = ApiToken.generate_for(@user)
    @auth_headers = { "Authorization" => "Bearer #{@raw_token}" }
    @recipe = recipes(:one)  # favorite: false
    @favorite_recipe = recipes(:three)  # favorite: true
  end

  test "update sets recipe as favorite" do
    assert_not @recipe.favorite

    put api_v1_recipe_favorite_url(@recipe), headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal @recipe.id, json["id"]
    assert json["favorite"]
    assert @recipe.reload.favorite
  end

  test "update is idempotent - can call multiple times" do
    put api_v1_recipe_favorite_url(@recipe), headers: @auth_headers, as: :json
    assert_response :success

    put api_v1_recipe_favorite_url(@recipe), headers: @auth_headers, as: :json
    assert_response :success
    assert @recipe.reload.favorite
  end

  test "update requires authentication" do
    put api_v1_recipe_favorite_url(@recipe), as: :json

    assert_response :unauthorized
  end

  test "update returns 404 for other user's recipe" do
    other_recipe = recipes(:two)

    put api_v1_recipe_favorite_url(other_recipe), headers: @auth_headers, as: :json

    assert_response :not_found
  end

  test "destroy removes recipe from favorites" do
    assert @favorite_recipe.favorite

    delete api_v1_recipe_favorite_url(@favorite_recipe), headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal @favorite_recipe.id, json["id"]
    assert_not json["favorite"]
    assert_not @favorite_recipe.reload.favorite
  end

  test "destroy is idempotent - can call multiple times" do
    delete api_v1_recipe_favorite_url(@recipe), headers: @auth_headers, as: :json
    assert_response :success

    delete api_v1_recipe_favorite_url(@recipe), headers: @auth_headers, as: :json
    assert_response :success
    assert_not @recipe.reload.favorite
  end

  test "destroy requires authentication" do
    delete api_v1_recipe_favorite_url(@recipe), as: :json

    assert_response :unauthorized
  end

  test "destroy returns 404 for other user's recipe" do
    other_recipe = recipes(:two)

    delete api_v1_recipe_favorite_url(other_recipe), headers: @auth_headers, as: :json

    assert_response :not_found
  end
end
