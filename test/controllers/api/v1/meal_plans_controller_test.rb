require "test_helper"

class Api::V1::MealPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @cookbook = cookbooks(:one_personal)
    _token_record, @raw_token = ApiToken.generate_for(@user)
    @auth_headers = {
      "Authorization" => "Bearer #{@raw_token}",
      "X-Cookbook-Id" => @cookbook.id.to_s
    }
  end

  # ===================
  # INDEX
  # ===================

  test "index returns meal plans for date range" do
    from = Date.today.iso8601
    to = Date.tomorrow.iso8601

    get api_v1_cookbook_meal_plans_url(@cookbook), params: { from: from, to: to }, headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_kind_of Array, json
    assert json.length >= 1

    plan = json.find { |p| p["date"] == Date.today.iso8601 }
    assert_not_nil plan
    assert plan.key?("entries")
    assert plan.key?("selected_entry_id")
    assert plan.key?("selected_at")
  end

  test "index returns entries with expected fields" do
    from = Date.today.iso8601
    to = Date.today.iso8601

    get api_v1_cookbook_meal_plans_url(@cookbook), params: { from: from, to: to }, headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    plan = json.first
    entry = plan["entries"].first

    assert entry.key?("id")
    assert entry.key?("recipe")
    assert entry.key?("proposed_by")
    assert entry.key?("vote_count")
    assert entry.key?("voted_by_current_user")
    assert entry["recipe"].key?("id")
    assert entry["recipe"].key?("name")
  end

  test "index returns empty array when no plans in range" do
    from = "2020-01-01"
    to = "2020-01-02"

    get api_v1_cookbook_meal_plans_url(@cookbook), params: { from: from, to: to }, headers: @auth_headers, as: :json

    assert_response :success
    assert_equal [], response.parsed_body
  end

  test "index returns 400 for invalid date" do
    get api_v1_cookbook_meal_plans_url(@cookbook), params: { from: "invalid", to: "2025-01-01" }, headers: @auth_headers, as: :json

    assert_response :bad_request
    assert_equal "Invalid date format. Use YYYY-MM-DD.", response.parsed_body["error"]
  end

  test "index requires authentication" do
    get api_v1_cookbook_meal_plans_url(@cookbook), params: { from: "2025-01-01", to: "2025-01-02" }, as: :json

    assert_response :unauthorized
  end

  test "index returns 403 for non-member cookbook" do
    other_cookbook = cookbooks(:two_personal)
    headers = {
      "Authorization" => "Bearer #{@raw_token}",
      "X-Cookbook-Id" => other_cookbook.id.to_s
    }

    get api_v1_cookbook_meal_plans_url(other_cookbook),
      params: { from: Date.today.iso8601, to: Date.today.iso8601 },
      headers: headers,
      as: :json

    assert_response :forbidden
  end

  test "index returns voted_by_current_user correctly" do
    from = Date.today.iso8601
    to = Date.today.iso8601

    get api_v1_cookbook_meal_plans_url(@cookbook), params: { from: from, to: to }, headers: @auth_headers, as: :json

    assert_response :success
    plan = response.parsed_body.first
    voted_entry = plan["entries"].find { |e| e["id"] == meal_plan_entries(:today_entry_one).id }
    unvoted_entry = plan["entries"].find { |e| e["id"] == meal_plan_entries(:today_entry_three).id }

    assert voted_entry["voted_by_current_user"]
    assert_not unvoted_entry["voted_by_current_user"]
  end
end
