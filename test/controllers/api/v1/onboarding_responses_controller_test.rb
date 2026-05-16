require "test_helper"

class Api::V1::OnboardingResponsesControllerTest < ActionDispatch::IntegrationTest
  test "create stores answers for an anonymous device" do
    assert_difference "OnboardingResponse.count", 1 do
      post api_v1_onboarding_response_url, params: {
        device_id: "$RCAnonymousID:new-device",
        answers: { household_size: 3, save_today: %w[screenshots notes] }
      }, as: :json
    end

    assert_response :created
    record = OnboardingResponse.find_by!(device_id: "$RCAnonymousID:new-device")
    assert_nil record.user_id
    assert_equal 3, record.answers["household_size"]
    assert_equal %w[screenshots notes], record.answers["save_today"]
  end

  test "create merges into existing record for the same device" do
    OnboardingResponse.create!(
      device_id: "$RCAnonymousID:merge-device",
      answers: { household_size: 2 }
    )

    assert_no_difference "OnboardingResponse.count" do
      post api_v1_onboarding_response_url, params: {
        device_id: "$RCAnonymousID:merge-device",
        answers: { diet: %w[vegetarian] }
      }, as: :json
    end

    assert_response :created
    record = OnboardingResponse.find_by!(device_id: "$RCAnonymousID:merge-device")
    assert_equal 2, record.answers["household_size"]
    assert_equal %w[vegetarian], record.answers["diet"]
  end

  test "create drops unknown keys" do
    post api_v1_onboarding_response_url, params: {
      device_id: "$RCAnonymousID:bad-key",
      answers: { household_size: 1, evil: "value" }
    }, as: :json
    assert_response :created
    record = OnboardingResponse.find_by!(device_id: "$RCAnonymousID:bad-key")
    assert_nil record.answers["evil"]
    assert_equal 1, record.answers["household_size"]
  end

  test "create rejects invalid save_today values" do
    post api_v1_onboarding_response_url, params: {
      device_id: "$RCAnonymousID:bad-save",
      answers: { save_today: %w[not_a_real_option] }
    }, as: :json
    assert_response :unprocessable_entity
  end

  test "create rejects non-integer household_size" do
    post api_v1_onboarding_response_url, params: {
      device_id: "$RCAnonymousID:bad-household",
      answers: { household_size: "two" }
    }, as: :json
    assert_response :unprocessable_entity
  end

  test "link_to_user! does not overwrite an already-linked response" do
    other = users(:two)
    response = OnboardingResponse.create!(
      device_id: "$RCAnonymousID:already-linked",
      answers: { household_size: 2 },
      user: other
    )

    OnboardingResponse.link_to_user!(device_id: "$RCAnonymousID:already-linked", user: users(:one))
    assert_equal other.id, response.reload.user_id
  end

  test "link_to_user! strips whitespace from device_id" do
    OnboardingResponse.create!(
      device_id: "$RCAnonymousID:whitespace",
      answers: { household_size: 1 }
    )

    OnboardingResponse.link_to_user!(device_id: "  $RCAnonymousID:whitespace  ", user: users(:one))
    assert_equal users(:one).id, OnboardingResponse.find_by(device_id: "$RCAnonymousID:whitespace").user_id
  end

  test "create requires device_id" do
    post api_v1_onboarding_response_url, params: { answers: { household_size: 1 } }, as: :json
    assert_response :unprocessable_entity
  end

  test "create requires answers to be an object" do
    post api_v1_onboarding_response_url, params: { device_id: "x", answers: "nope" }, as: :json
    assert_response :unprocessable_entity
  end

  test "create does not require authentication" do
    post api_v1_onboarding_response_url, params: {
      device_id: "$RCAnonymousID:no-auth",
      answers: { household_size: 1 }
    }, as: :json
    assert_response :created
  end

  test "signup links existing anonymous response to the new user" do
    OnboardingResponse.create!(
      device_id: "$RCAnonymousID:signup-link",
      answers: { household_size: 5 }
    )

    post api_v1_registration_url, params: {
      email: "linker@example.com",
      password: "password",
      password_confirmation: "password",
      onboarding_device_id: "$RCAnonymousID:signup-link"
    }, as: :json

    assert_response :created
    user = User.find_by!(email_address: "linker@example.com")
    assert_equal user.id, OnboardingResponse.find_by(device_id: "$RCAnonymousID:signup-link").user_id
  end

  test "login links existing anonymous response to the user" do
    OnboardingResponse.create!(
      device_id: "$RCAnonymousID:login-link",
      answers: { diet: %w[vegan] }
    )

    post api_v1_session_url, params: {
      email: users(:one).email_address,
      password: "password",
      onboarding_device_id: "$RCAnonymousID:login-link"
    }, as: :json

    assert_response :created
    assert_equal users(:one).id, OnboardingResponse.find_by(device_id: "$RCAnonymousID:login-link").user_id
  end
end
