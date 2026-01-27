RubyLLM.configure do |config|
  # Use a dummy key in test environment (WebMock intercepts all HTTP requests)
  # This satisfies RubyLLM's configuration validation without exposing real credentials
  config.openrouter_api_key = if Rails.env.test?
    "test-dummy-key"
  else
    Rails.application.credentials.dig(:openrouter, :api_key)
  end
end
