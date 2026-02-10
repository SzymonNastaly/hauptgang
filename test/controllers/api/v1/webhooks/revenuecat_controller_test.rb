require "test_helper"

class Api::V1::Webhooks::RevenuecatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @webhook_url = api_v1_webhooks_revenuecat_url
  end

  test "sets user pro when entitlement is active" do
    assert_not @user.pro?

    post @webhook_url, params: webhook_payload(
      app_user_id: @user.id,
      entitlement_active: true,
      expires_date: 1.month.from_now.iso8601
    ), as: :json

    assert_response :ok
    assert @user.reload.pro?
  end

  test "removes pro when entitlement is expired" do
    @user.update!(pro: true)

    post @webhook_url, params: webhook_payload(
      app_user_id: @user.id,
      entitlement_active: true,
      expires_date: 1.day.ago.iso8601
    ), as: :json

    assert_response :ok
    assert_not @user.reload.pro?
  end

  test "removes pro when entitlement is absent" do
    @user.update!(pro: true)

    post @webhook_url, params: webhook_payload(
      app_user_id: @user.id,
      entitlement_active: false
    ), as: :json

    assert_response :ok
    assert_not @user.reload.pro?
  end

  test "returns 200 for unknown user" do
    post @webhook_url, params: webhook_payload(
      app_user_id: 999999,
      entitlement_active: true,
      expires_date: 1.month.from_now.iso8601
    ), as: :json

    assert_response :ok
  end

  test "returns 401 with invalid authorization when secret is configured" do
    with_webhook_secret("correct-secret") do
      post @webhook_url,
        params: webhook_payload(app_user_id: @user.id, entitlement_active: true),
        headers: { "Authorization" => "wrong-secret" },
        as: :json

      assert_response :unauthorized
    end
  end

  test "accepts request with valid authorization when secret is configured" do
    secret = "test-webhook-secret"
    with_webhook_secret(secret) do
      post @webhook_url,
        params: webhook_payload(
          app_user_id: @user.id,
          entitlement_active: true,
          expires_date: 1.month.from_now.iso8601
        ),
        headers: { "Authorization" => secret },
        as: :json

      assert_response :ok
      assert @user.reload.pro?
    end
  end

  private

  def with_webhook_secret(secret)
    ENV["REVENUECAT_WEBHOOK_SECRET"] = secret
    yield
  ensure
    ENV.delete("REVENUECAT_WEBHOOK_SECRET")
  end

  def webhook_payload(app_user_id:, entitlement_active:, expires_date: nil)
    entitlements = if entitlement_active
      {
        "Hauptgang Pro" => {
          "expires_date" => expires_date,
          "purchase_date" => 1.month.ago.iso8601
        }
      }
    else
      {}
    end

    {
      event: {
        type: "RENEWAL",
        app_user_id: app_user_id.to_s,
        subscriber_info: {
          entitlements: entitlements
        }
      }
    }
  end
end
