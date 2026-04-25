require "test_helper"

class Apns::ClientTest < ActiveSupport::TestCase
  STUB_PEM = <<~PEM
    -----BEGIN PRIVATE KEY-----
    MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAChRANCAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    -----END PRIVATE KEY-----
  PEM

  setup do
    @creds_stub = {
      team_id: "TEAM12345",
      key_id: "KEYID67890",
      bundle_id: "app.hauptgang.ios",
      auth_key: STUB_PEM
    }
  end

  teardown do
    Apns::Client.reset!
  end

  test "build_pool returns an Apnotic::ConnectionPool without raising LocalJumpError" do
    Rails.application.credentials.stub(:apns, @creds_stub) do
      assert_nothing_raised do
        pool = Apns::Client.send(:connection_for, "sandbox")
        assert_kind_of ::ConnectionPool, pool
      end
    end
  end

  test "build_pool builds distinct pools per environment" do
    Rails.application.credentials.stub(:apns, @creds_stub) do
      sandbox = Apns::Client.send(:connection_for, "sandbox")
      production = Apns::Client.send(:connection_for, "production")
      assert_not_same sandbox, production
    end
  end
end
