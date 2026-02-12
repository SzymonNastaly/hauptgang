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

  test "batch returns recipe details with cursor paging" do
    recipe1 = recipes(:one)
    recipe2 = recipes(:three)

    recipe1.update!(updated_at: 2.days.ago)
    recipe2.update!(updated_at: 1.day.ago)

    get batch_api_v1_recipes_url, params: { limit: 1 }, headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["recipes"].length
    assert json["next_cursor"].present?
    assert_equal recipe1.id, json["recipes"].first["id"]

    get batch_api_v1_recipes_url,
      params: { limit: 1, cursor: json["next_cursor"] },
      headers: @auth_headers,
      as: :json

    assert_response :success
    json2 = response.parsed_body
    assert_equal [ recipe2.id ], json2["recipes"].map { |r| r["id"] }
  end

  test "batch returns 422 for invalid cursor" do
    get batch_api_v1_recipes_url, params: { cursor: "invalid" }, headers: @auth_headers, as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "Invalid cursor", json["error"]
  end

  test "batch requires authentication" do
    get batch_api_v1_recipes_url, as: :json

    assert_response :unauthorized
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

  test "import creates recipe and enqueues job" do
    assert_enqueued_with(job: RecipeImportJob) do
      post import_api_v1_recipes_url,
        params: { url: "https://example.com/recipe" },
        headers: @auth_headers,
        as: :json
    end

    assert_response :accepted
    json = response.parsed_body
    assert json["id"].present?
    assert_equal "pending", json["import_status"]

    recipe = Recipe.find(json["id"])
    assert_equal "Importing...", recipe.name
    assert_equal "https://example.com/recipe", recipe.source_url
    assert_equal @user.id, recipe.user_id
  end

  test "import returns error for blank URL" do
    post import_api_v1_recipes_url,
      params: { url: "" },
      headers: @auth_headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "URL is required", json["error"]
  end

  test "import returns error for invalid URL" do
    post import_api_v1_recipes_url,
      params: { url: "not-a-url" },
      headers: @auth_headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?
  end

  test "import returns error for localhost URL" do
    post import_api_v1_recipes_url,
      params: { url: "http://localhost/recipe" },
      headers: @auth_headers,
      as: :json

    assert_response :unprocessable_entity
  end

  test "import requires authentication" do
    post import_api_v1_recipes_url,
      params: { url: "https://example.com/recipe" },
      as: :json

    assert_response :unauthorized
  end

  # extract_from_text tests

  test "extract_from_text creates recipe and enqueues job" do
    text = "Chocolate Cake\n\nIngredients:\n- 2 cups flour"

    assert_enqueued_with(job: RecipeTextExtractJob) do
      post extract_from_text_api_v1_recipes_url,
        params: { text: text },
        headers: @auth_headers,
        as: :json
    end

    assert_response :accepted
    json = response.parsed_body
    assert json["id"].present?
    assert_equal "pending", json["import_status"]

    recipe = Recipe.find(json["id"])
    assert_equal "Importing...", recipe.name
    assert_nil recipe.source_url
    assert_equal @user.id, recipe.user_id
  end

  test "extract_from_text returns error for blank text" do
    post extract_from_text_api_v1_recipes_url,
      params: { text: "" },
      headers: @auth_headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "Text is required", json["error"]
  end

  test "extract_from_text returns error for text too long" do
    long_text = "a" * 50_001

    post extract_from_text_api_v1_recipes_url,
      params: { text: long_text },
      headers: @auth_headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "Text too long (max 50,000 chars)", json["error"]
  end

  test "extract_from_text requires authentication" do
    post extract_from_text_api_v1_recipes_url,
      params: { text: "Some recipe text" },
      as: :json

    assert_response :unauthorized
  end

  # extract_from_image tests

  test "extract_from_image creates recipe and enqueues job" do
    image = fixture_file_upload("test/fixtures/files/test_image.png", "image/png")

    assert_enqueued_with(job: RecipeImageExtractJob) do
      post extract_from_image_api_v1_recipes_url,
        params: { image: image },
        headers: @auth_headers
    end

    assert_response :accepted
    json = response.parsed_body
    assert json["id"].present?
    assert_equal "pending", json["import_status"]

    recipe = Recipe.find(json["id"])
    assert_equal "Importing...", recipe.name
    assert_equal @user.id, recipe.user_id
    assert recipe.import_image.attached?
    assert_not recipe.cover_image.attached?
  end

  test "extract_from_image returns error for blank image" do
    post extract_from_image_api_v1_recipes_url,
      params: { image: nil },
      headers: @auth_headers

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "Image is required", json["error"]
  end

  test "extract_from_image returns error for non-image upload" do
    file = fixture_file_upload("test/fixtures/files/test.txt", "text/plain")

    post extract_from_image_api_v1_recipes_url,
      params: { image: file },
      headers: @auth_headers

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "Image must be an image", json["error"]
  end

  test "extract_from_image requires authentication" do
    image = fixture_file_upload("test/fixtures/files/test_image.png", "image/png")

    post extract_from_image_api_v1_recipes_url,
      params: { image: image }

    assert_response :unauthorized
  end

  # Failed recipe handling tests

  test "index tracks first fetch of failed recipes" do
    recipe = @user.recipes.create!(
      name: "Failed Import",
      import_status: :failed,
      error_message: "Import from example.com failed."
    )
    assert_nil recipe.failed_recipe_fetched_at

    get api_v1_recipes_url, headers: @auth_headers, as: :json

    recipe.reload
    assert_not_nil recipe.failed_recipe_fetched_at
    assert_in_delta Time.current, recipe.failed_recipe_fetched_at, 2.seconds
  end

  test "index deletes failed recipes after 1 minute" do
    recipe = @user.recipes.create!(
      name: "Failed Import",
      import_status: :failed,
      error_message: "Import from example.com failed.",
      failed_recipe_fetched_at: 2.minutes.ago
    )

    assert_difference "@user.recipes.count", -1 do
      get api_v1_recipes_url, headers: @auth_headers, as: :json
    end

    assert_raises(ActiveRecord::RecordNotFound) { recipe.reload }
  end

  test "index does not delete recently fetched failed recipes" do
    recipe = @user.recipes.create!(
      name: "Failed Import",
      import_status: :failed,
      error_message: "Import from example.com failed.",
      failed_recipe_fetched_at: 30.seconds.ago
    )

    assert_no_difference "@user.recipes.count" do
      get api_v1_recipes_url, headers: @auth_headers, as: :json
    end

    assert_nothing_raised { recipe.reload }
  end

  test "index includes error_message in recipe list JSON" do
    @user.recipes.create!(
      name: "Failed Import",
      import_status: :failed,
      error_message: "Import from test.com failed."
    )

    get api_v1_recipes_url, headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    failed_recipe = json.find { |r| r["name"] == "Failed Import" }

    assert_not_nil failed_recipe
    assert_equal "Import from test.com failed.", failed_recipe["error_message"]
    assert_equal "failed", failed_recipe["import_status"]
  end

  # MARK: - Destroy Tests

  test "destroy returns 204 on successful deletion" do
    recipe = @user.recipes.create!(name: "To Delete")

    delete api_v1_recipe_url(recipe), headers: @auth_headers, as: :json

    assert_response :no_content
    assert_nil Recipe.find_by(id: recipe.id)
  end

  test "destroy returns 404 for non-existent recipe" do
    delete api_v1_recipe_url(id: 999999), headers: @auth_headers, as: :json

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Recipe not found", json["error"]
  end

  test "destroy returns 404 when trying to delete another user's recipe" do
    other_recipe = @other_user.recipes.create!(name: "Other User's Recipe")

    delete api_v1_recipe_url(other_recipe), headers: @auth_headers, as: :json

    assert_response :not_found
    assert Recipe.exists?(other_recipe.id)
  end

  test "destroy requires authentication" do
    recipe = @user.recipes.create!(name: "Protected Recipe")

    delete api_v1_recipe_url(recipe), as: :json

    assert_response :unauthorized
    assert Recipe.exists?(recipe.id)
  end
end
