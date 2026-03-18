require "test_helper"

class Api::V1::MealPlanVotesControllerTest < ActionDispatch::IntegrationTest
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
  # CREATE (vote)
  # ===================

  test "create adds vote for current user" do
    entry = meal_plan_entries(:today_entry_three)

    assert_difference "MealPlanVote.count", 1 do
      post api_v1_meal_plan_entry_vote_url(entry), headers: @auth_headers, as: :json
    end

    assert_response :success
    json = response.parsed_body
    voted_entry = json["entries"].find { |e| e["id"] == entry.id }
    assert voted_entry["voted_by_current_user"]
  end

  test "create is idempotent" do
    entry = meal_plan_entries(:today_entry_one) # already voted by user one

    assert_no_difference "MealPlanVote.count" do
      post api_v1_meal_plan_entry_vote_url(entry), headers: @auth_headers, as: :json
    end

    assert_response :success
  end

  test "create blocks when plan is selected" do
    entry = meal_plan_entries(:selected_entry)

    post api_v1_meal_plan_entry_vote_url(entry), headers: @auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_match "finalized", response.parsed_body["error"]
  end

  test "create returns full meal plan JSON" do
    entry = meal_plan_entries(:today_entry_three)

    post api_v1_meal_plan_entry_vote_url(entry), headers: @auth_headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert json.key?("date")
    assert json.key?("entries")
    assert json.key?("selected_entry_id")
  end

  test "create returns 404 for entry in other cookbook" do
    entry = meal_plan_entries(:other_cookbook_entry)

    post api_v1_meal_plan_entry_vote_url(entry), headers: @auth_headers, as: :json

    assert_response :not_found
  end

  # ===================
  # DESTROY (unvote)
  # ===================

  test "destroy removes vote for current user" do
    entry = meal_plan_entries(:today_entry_one)

    assert_difference "MealPlanVote.count", -1 do
      delete api_v1_meal_plan_entry_vote_url(entry), headers: @auth_headers, as: :json
    end

    assert_response :success
    json = response.parsed_body
    voted_entry = json["entries"].find { |e| e["id"] == entry.id }
    assert_not voted_entry["voted_by_current_user"]
  end

  test "destroy is safe when no vote exists" do
    entry = meal_plan_entries(:today_entry_three)

    assert_no_difference "MealPlanVote.count" do
      delete api_v1_meal_plan_entry_vote_url(entry), headers: @auth_headers, as: :json
    end

    assert_response :success
  end

  test "destroy blocks when plan is selected" do
    entry = meal_plan_entries(:selected_entry)

    delete api_v1_meal_plan_entry_vote_url(entry), headers: @auth_headers, as: :json

    assert_response :unprocessable_entity
  end

  test "destroy returns 404 for entry in other cookbook" do
    entry = meal_plan_entries(:other_cookbook_entry)

    delete api_v1_meal_plan_entry_vote_url(entry), headers: @auth_headers, as: :json

    assert_response :not_found
  end

  test "destroy requires authentication" do
    entry = meal_plan_entries(:today_entry_one)

    delete api_v1_meal_plan_entry_vote_url(entry), as: :json

    assert_response :unauthorized
  end
end
