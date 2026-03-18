require "test_helper"

class Api::V1::MealPlanSelectionsControllerTest < ActionDispatch::IntegrationTest
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
  # UPDATE (select)
  # ===================

  test "update selects entry for date" do
    plan = meal_plans(:today_plan)
    entry = meal_plan_entries(:today_entry_one)

    patch date_select_api_v1_cookbook_meal_plans_url(@cookbook, plan.date.iso8601),
      params: { entry_id: entry.id },
      headers: @auth_headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal entry.id, json["selected_entry_id"]
    assert_not_nil json["selected_at"]

    plan.reload
    assert plan.selected?
    assert_equal entry.id, plan.selected_entry_id
    assert_equal @user.id, plan.selected_by_user_id
  end

  test "update is idempotent for same entry" do
    plan = meal_plans(:selected_plan)
    entry = meal_plan_entries(:selected_entry)

    patch date_select_api_v1_cookbook_meal_plans_url(@cookbook, plan.date.iso8601),
      params: { entry_id: entry.id },
      headers: @auth_headers,
      as: :json

    assert_response :success
    assert_equal entry.id, response.parsed_body["selected_entry_id"]
  end

  test "update returns 409 when different entry already selected" do
    plan = meal_plans(:selected_plan)
    # Add another entry to this plan
    recipe = @cookbook.recipes.create!(name: "Other Pick", user: @user)
    other_entry = plan.entries.create!(recipe: recipe, proposed_by_user: @user)

    patch date_select_api_v1_cookbook_meal_plans_url(@cookbook, plan.date.iso8601),
      params: { entry_id: other_entry.id },
      headers: @auth_headers,
      as: :json

    assert_response :conflict
    assert_match "already been selected", response.parsed_body["error"]
  end

  test "update returns 404 for missing meal plan" do
    patch date_select_api_v1_cookbook_meal_plans_url(@cookbook, "2099-12-31"),
      params: { entry_id: 1 },
      headers: @auth_headers,
      as: :json

    assert_response :not_found
  end

  test "update returns 400 for invalid date" do
    patch date_select_api_v1_cookbook_meal_plans_url(@cookbook, "invalid"),
      params: { entry_id: 1 },
      headers: @auth_headers,
      as: :json

    assert_response :bad_request
  end

  test "update returns 403 for non-member cookbook" do
    other_cookbook = cookbooks(:two_personal)
    headers = {
      "Authorization" => "Bearer #{@raw_token}",
      "X-Cookbook-Id" => other_cookbook.id.to_s
    }

    patch date_select_api_v1_cookbook_meal_plans_url(other_cookbook, Date.today.iso8601),
      params: { entry_id: 1 },
      headers: headers,
      as: :json

    assert_response :forbidden
  end

  test "update requires authentication" do
    plan = meal_plans(:today_plan)
    entry = meal_plan_entries(:today_entry_one)

    patch date_select_api_v1_cookbook_meal_plans_url(@cookbook, plan.date.iso8601),
      params: { entry_id: entry.id },
      as: :json

    assert_response :unauthorized
  end

  # ===================
  # DESTROY (deselect)
  # ===================

  test "destroy deselects meal plan" do
    plan = meal_plans(:selected_plan)

    delete date_select_api_v1_cookbook_meal_plans_url(@cookbook, plan.date.iso8601),
      headers: @auth_headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_nil json["selected_entry_id"]
    assert_nil json["selected_at"]

    plan.reload
    assert_not plan.selected?
  end

  test "destroy is safe when not selected" do
    plan = meal_plans(:today_plan)

    delete date_select_api_v1_cookbook_meal_plans_url(@cookbook, plan.date.iso8601),
      headers: @auth_headers,
      as: :json

    assert_response :success
  end

  test "destroy returns 404 for missing meal plan" do
    delete date_select_api_v1_cookbook_meal_plans_url(@cookbook, "2099-12-31"),
      headers: @auth_headers,
      as: :json

    assert_response :not_found
  end

  test "destroy returns 403 for non-member cookbook" do
    other_cookbook = cookbooks(:two_personal)
    headers = {
      "Authorization" => "Bearer #{@raw_token}",
      "X-Cookbook-Id" => other_cookbook.id.to_s
    }

    delete date_select_api_v1_cookbook_meal_plans_url(other_cookbook, Date.today.iso8601),
      headers: headers,
      as: :json

    assert_response :forbidden
  end

  test "destroy returns 400 for invalid date" do
    delete date_select_api_v1_cookbook_meal_plans_url(@cookbook, "invalid"),
      headers: @auth_headers,
      as: :json

    assert_response :bad_request
  end
end
