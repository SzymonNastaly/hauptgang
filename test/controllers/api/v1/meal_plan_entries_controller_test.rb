require "test_helper"

class Api::V1::MealPlanEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @cookbook = cookbooks(:one_personal)
    @recipe = recipes(:one)
    _token_record, @raw_token = ApiToken.generate_for(@user)
    @auth_headers = {
      "Authorization" => "Bearer #{@raw_token}",
      "X-Cookbook-Id" => @cookbook.id.to_s
    }
  end

  # ===================
  # CREATE
  # ===================

  test "create adds entry to meal plan" do
    recipe = @cookbook.recipes.create!(name: "New Recipe", user: @user)
    date = 10.days.from_now.to_date.iso8601

    assert_difference "MealPlanEntry.count", 1 do
      post date_entries_api_v1_cookbook_meal_plans_url(@cookbook, date),
        params: { recipe_id: recipe.id },
        headers: @auth_headers,
        as: :json
    end

    assert_response :created
    json = response.parsed_body
    assert_equal date, json["date"]
    assert json["entries"].any? { |e| e["recipe"]["id"] == recipe.id }
  end

  test "create is idempotent for same recipe and date" do
    date = Date.today.iso8601

    assert_no_difference "MealPlanEntry.count" do
      post date_entries_api_v1_cookbook_meal_plans_url(@cookbook, date),
        params: { recipe_id: @recipe.id },
        headers: @auth_headers,
        as: :json
    end

    assert_response :ok
  end

  test "create auto-creates meal plan for new date" do
    date = 20.days.from_now.to_date.iso8601
    recipe = @cookbook.recipes.create!(name: "Another Recipe", user: @user)

    assert_difference "MealPlan.count", 1 do
      post date_entries_api_v1_cookbook_meal_plans_url(@cookbook, date),
        params: { recipe_id: recipe.id },
        headers: @auth_headers,
        as: :json
    end

    assert_response :created
  end

  test "create blocks when plan is already selected" do
    selected_plan = meal_plans(:selected_plan)
    recipe = @cookbook.recipes.create!(name: "Blocked Recipe", user: @user)

    post date_entries_api_v1_cookbook_meal_plans_url(@cookbook, selected_plan.date.iso8601),
      params: { recipe_id: recipe.id },
      headers: @auth_headers,
      as: :json

    assert_response :unprocessable_entity
    assert_match "finalized", response.parsed_body["error"]
  end

  test "create returns 404 for recipe not in cookbook" do
    other_recipe = recipes(:two)
    date = Date.today.iso8601

    post date_entries_api_v1_cookbook_meal_plans_url(@cookbook, date),
      params: { recipe_id: other_recipe.id },
      headers: @auth_headers,
      as: :json

    assert_response :not_found
  end

  test "create returns 400 for invalid date" do
    post date_entries_api_v1_cookbook_meal_plans_url(@cookbook, "invalid"),
      params: { recipe_id: @recipe.id },
      headers: @auth_headers,
      as: :json

    assert_response :bad_request
  end

  test "create returns 403 for non-member cookbook" do
    other_cookbook = cookbooks(:two_personal)
    headers = {
      "Authorization" => "Bearer #{@raw_token}",
      "X-Cookbook-Id" => other_cookbook.id.to_s
    }

    post date_entries_api_v1_cookbook_meal_plans_url(other_cookbook, Date.today.iso8601),
      params: { recipe_id: @recipe.id },
      headers: headers,
      as: :json

    assert_response :forbidden
  end

  test "create requires authentication" do
    post date_entries_api_v1_cookbook_meal_plans_url(@cookbook, Date.today.iso8601),
      params: { recipe_id: @recipe.id },
      as: :json

    assert_response :unauthorized
  end

  # ===================
  # DESTROY
  # ===================

  test "destroy removes entry" do
    entry = meal_plan_entries(:today_entry_three)

    assert_difference "MealPlanEntry.count", -1 do
      delete api_v1_meal_plan_entry_url(entry), headers: @auth_headers, as: :json
    end

    assert_response :no_content
  end

  test "destroy blocks when plan is selected" do
    entry = meal_plan_entries(:selected_entry)

    assert_no_difference "MealPlanEntry.count" do
      delete api_v1_meal_plan_entry_url(entry), headers: @auth_headers, as: :json
    end

    assert_response :unprocessable_entity
    assert_match "finalized", response.parsed_body["error"]
  end

  test "destroy returns 404 for entry in other cookbook" do
    entry = meal_plan_entries(:other_cookbook_entry)

    delete api_v1_meal_plan_entry_url(entry), headers: @auth_headers, as: :json

    assert_response :not_found
  end

  test "destroy returns 404 for nonexistent entry" do
    delete api_v1_meal_plan_entry_url(id: 999999), headers: @auth_headers, as: :json

    assert_response :not_found
  end
end
