# Helper methods for system tests
# These make tests more readable and less brittle

module SystemTestHelper
  # ===================
  # AUTHENTICATION
  # ===================

  # Sign in via the UI (for system tests)
  # This simulates a real user logging in through the form
  def sign_in_via_ui(user, password: "password")
    visit new_session_path

    # Use Capybara's native fill_in with placeholder text (more reliable)
    fill_in "Enter your email address", with: user.email_address
    fill_in "Enter your password", with: password

    click_button "Sign in"

    # Wait for page load and check we navigated away
    # Use has_no_current_path? with wait to handle Turbo navigation
    using_wait_time(5) do
      assert has_no_current_path?(new_session_path, wait: 5),
        "Login failed - still on login page. Check credentials or look for error message."
    end
  end

  # Helper to check current path with wait
  def has_no_current_path?(path, wait: Capybara.default_max_wait_time)
    start_time = Time.now
    loop do
      return true if current_path != path
      return false if Time.now - start_time > wait
      sleep 0.1
    end
  end

  # ===================
  # TEST ID HELPERS
  # ===================
  # These helpers make tests resilient to CSS/HTML changes

  # Find element by data-testid attribute
  # Use visible: :all to find elements that may be in complex layouts (masonry, etc.)
  def find_testid(testid, visible: :visible, **options)
    find("[data-testid='#{testid}']", visible: visible, **options)
  end

  # Click element by data-testid (scrolls into view if needed)
  def click_testid(testid, **options)
    element = find_testid(testid, **options)
    scroll_to(element)
    element.click
  end

  # Fill in a field by data-testid (uses .set for input elements)
  def fill_in_testid(testid, with:)
    find_testid(testid).set(with)
  end

  # Check if element with testid exists (visible or not)
  def has_testid?(testid)
    has_selector?("[data-testid='#{testid}']", visible: :all)
  end

  # Check if element with testid does not exist
  def has_no_testid?(testid)
    has_no_selector?("[data-testid='#{testid}']", visible: :all)
  end

  # Assert element with testid exists (visible: :all handles complex layouts)
  def assert_testid(testid)
    assert_selector("[data-testid='#{testid}']", visible: :all)
  end

  # Assert element with testid is not present
  def assert_no_testid(testid)
    assert_no_selector("[data-testid='#{testid}']", visible: :all)
  end

  # ===================
  # NAVIGATION HELPERS
  # ===================

  # Assert we're on a specific path
  def assert_current_path(path)
    assert_equal path, current_path
  end

  # Assert we're NOT on a specific path (useful after redirects)
  def assert_no_current_path(path)
    assert_not_equal path, current_path
  end
end
