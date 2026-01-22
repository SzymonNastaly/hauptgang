require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  test "signing in with valid credentials" do
    user = users(:one)

    visit new_session_path

    find("[data-testid='email-input']").fill_in with: user.email_address
    find("[data-testid='password-input']").fill_in with: "password"
    find("[data-testid='sign-in-button']").click

    assert_current_path root_path
  end
end
