require "test_helper"

class Api::V1::RecipesControllerImportLimitTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    _token_record, @raw_token = ApiToken.generate_for(@user)
    @auth_headers = { "Authorization" => "Bearer #{@raw_token}" }
  end

  test "import returns 403 when limit reached" do
    fill_import_limit(@user)

    post import_api_v1_recipes_url,
      params: { url: "https://example.com/recipe" },
      headers: @auth_headers,
      as: :json

    assert_response :forbidden
    json = response.parsed_body
    assert_equal "import_limit_reached", json["error_code"]
    assert_equal "Monthly import limit reached", json["error"]
    assert_equal User::FREE_MONTHLY_IMPORT_LIMIT, json["limit"]
  end

  test "extract_from_text returns 403 when limit reached" do
    fill_import_limit(@user)

    post extract_from_text_api_v1_recipes_url,
      params: { text: "Some recipe" },
      headers: @auth_headers,
      as: :json

    assert_response :forbidden
    json = response.parsed_body
    assert_equal "import_limit_reached", json["error_code"]
  end

  test "extract_from_image returns 403 when limit reached" do
    fill_import_limit(@user)
    image = fixture_file_upload("test/fixtures/files/test_image.png", "image/png")

    post extract_from_image_api_v1_recipes_url,
      params: { image: image },
      headers: @auth_headers

    assert_response :forbidden
    json = response.parsed_body
    assert_equal "import_limit_reached", json["error_code"]
  end

  test "pro users bypass import limit" do
    @user.update!(pro: true)
    fill_import_limit(@user)

    assert_enqueued_with(job: RecipeImportJob) do
      post import_api_v1_recipes_url,
        params: { url: "https://example.com/recipe" },
        headers: @auth_headers,
        as: :json
    end

    assert_response :accepted
  end

  test "import still works when under limit" do
    assert_enqueued_with(job: RecipeImportJob) do
      post import_api_v1_recipes_url,
        params: { url: "https://example.com/recipe" },
        headers: @auth_headers,
        as: :json
    end

    assert_response :accepted
  end

  private

  def fill_import_limit(user)
    needed = User::FREE_MONTHLY_IMPORT_LIMIT - user.monthly_import_count
    needed.times { |i| user.recipes.create!(name: "Limit Recipe #{i}", import_status: :completed) }
  end
end
