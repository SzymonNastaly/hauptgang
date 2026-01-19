require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "generate_for creates a token and returns raw value" do
    token_record, raw_token = ApiToken.generate_for(@user, name: "Test Device")

    assert token_record.persisted?
    assert_equal @user, token_record.user
    assert_equal "Test Device", token_record.name
    assert_not_nil token_record.expires_at
    assert token_record.expires_at > Time.current
    assert_not_nil raw_token
    assert raw_token.length > 20
  end

  test "find_by_raw_token finds active token" do
    token_record, raw_token = ApiToken.generate_for(@user)

    found = ApiToken.find_by_raw_token(raw_token)

    assert_equal token_record, found
  end

  test "find_by_raw_token returns nil for invalid token" do
    found = ApiToken.find_by_raw_token("invalid_token")

    assert_nil found
  end

  test "find_by_raw_token returns nil for blank token" do
    assert_nil ApiToken.find_by_raw_token(nil)
    assert_nil ApiToken.find_by_raw_token("")
  end

  test "find_by_raw_token excludes revoked tokens" do
    found = ApiToken.find_by_raw_token("test_token_revoked")

    assert_nil found
  end

  test "find_by_raw_token excludes expired tokens" do
    found = ApiToken.find_by_raw_token("test_token_expired")

    assert_nil found
  end

  test "revoke! sets revoked_at" do
    token = api_tokens(:active)

    token.revoke!

    assert_not_nil token.revoked_at
    assert token.revoked?
  end

  test "active? returns true for valid token" do
    token_record, _raw = ApiToken.generate_for(@user)

    assert token_record.active?
  end

  test "active? returns false for revoked token" do
    token = api_tokens(:revoked)

    assert_not token.active?
  end

  test "active? returns false for expired token" do
    token = api_tokens(:expired)

    assert_not token.active?
  end

  test "touch_last_used! updates last_used_at" do
    token_record, _raw = ApiToken.generate_for(@user)
    assert_nil token_record.last_used_at

    token_record.touch_last_used!

    assert_not_nil token_record.last_used_at
  end

  test "touch_last_used! is throttled" do
    token_record, _raw = ApiToken.generate_for(@user)
    token_record.update_column(:last_used_at, 1.minute.ago)
    original_time = token_record.last_used_at

    token_record.touch_last_used!

    assert_equal original_time, token_record.reload.last_used_at
  end

  test "active scope excludes revoked and expired tokens" do
    active_tokens = ApiToken.active

    assert_includes active_tokens, api_tokens(:active)
    assert_not_includes active_tokens, api_tokens(:revoked)
    assert_not_includes active_tokens, api_tokens(:expired)
  end
end
