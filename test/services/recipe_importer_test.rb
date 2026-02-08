require "test_helper"

class RecipeImporterTest < ActiveSupport::TestCase
  # ===================
  # VALIDATION TESTS
  # ===================

  test "returns error for blank URL" do
    result = RecipeImporter.new("").import
    assert_not result.success?
    assert_equal "Please enter a URL", result.error
    assert_equal :blank_url, result.error_code
  end

  test "returns error for nil URL" do
    result = RecipeImporter.new(nil).import
    assert_not result.success?
    assert_equal "Please enter a URL", result.error
    assert_equal :blank_url, result.error_code
  end

  # ===================
  # SSRF PROTECTION TESTS
  # ===================

  test "blocks localhost URLs" do
    result = RecipeImporter.new("http://localhost/recipe").import
    assert_not result.success?
    assert_equal :invalid_url, result.error_code
  end

  test "blocks private IP URLs" do
    result = RecipeImporter.new("http://192.168.1.1/recipe").import
    assert_not result.success?
    assert_equal :invalid_url, result.error_code
  end

  test "blocks file:// scheme" do
    result = RecipeImporter.new("file:///etc/passwd").import
    assert_not result.success?
    assert_equal :invalid_url, result.error_code
  end

  # ===================
  # HTTP FETCH TESTS
  # ===================

  test "returns error when page cannot be fetched" do
    stub_request(:get, "https://example.com/recipe")
      .to_return(status: 404, headers: { "Content-Type" => "text/html" })

    result = RecipeImporter.new("https://example.com/recipe").import

    assert_not result.success?
    assert_equal "Could not fetch the page", result.error
    assert_equal :fetch_failed, result.error_code
  end

  test "returns error on network timeout" do
    # Use .to_raise instead of .to_timeout because WebMock's .to_timeout
    # raises Faraday::ConnectionFailed, not Faraday::TimeoutError
    stub_request(:get, "https://example.com/recipe")
      .to_raise(Faraday::TimeoutError)

    result = RecipeImporter.new("https://example.com/recipe").import

    assert_not result.success?
    assert_equal "The page took too long to load", result.error
    assert_equal :timeout, result.error_code
  end

  test "returns error for invalid URL format" do
    result = RecipeImporter.new("not-a-valid-url").import

    assert_not result.success?
    assert_equal :invalid_url, result.error_code
  end

  test "returns error for non-HTML content type" do
    stub_request(:get, "https://example.com/api/recipe.json")
      .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

    result = RecipeImporter.new("https://example.com/api/recipe.json").import

    assert_not result.success?
    assert_equal "The URL does not appear to be a web page", result.error
    assert_equal :invalid_content_type, result.error_code
  end

  test "follows redirects up to limit" do
    stub_request(:get, "https://example.com/old-recipe")
      .to_return(status: 301, headers: { "Location" => "https://example.com/new-recipe" })

    stub_request(:get, "https://example.com/new-recipe")
      .to_return(
        status: 200,
        body: '<html><head><script type="application/ld+json">{"@type":"Recipe","name":"Redirected"}</script></head></html>',
        headers: { "Content-Type" => "text/html" }
      )

    result = RecipeImporter.new("https://example.com/old-recipe").import

    assert result.success?
    assert_equal "Redirected", result.recipe_attributes[:name]
  end

  # ===================
  # EXTRACTION FLOW TESTS
  # ===================

  test "successfully extracts recipe from JSON-LD" do
    html = <<~HTML
      <html>
      <head>
        <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": ["1 cup flour"],
            "recipeInstructions": ["Mix well"]
          }
        </script>
      </head>
      <body></body>
      </html>
    HTML

    stub_request(:get, "https://example.com/recipe")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    result = RecipeImporter.new("https://example.com/recipe").import

    assert result.success?
    assert_equal "Test Recipe", result.recipe_attributes[:name]
    assert_equal [ "1 cup flour" ], result.recipe_attributes[:ingredients]
    assert_equal [ "Mix well" ], result.recipe_attributes[:instructions]
    assert_equal "https://example.com/recipe", result.recipe_attributes[:source_url]
  end

  test "imports instagram reel via apify" do
    url = "https://www.instagram.com/p/DRUf_pBiPdh/"
    previous_key = ENV["APIFY_API_KEY"]
    ENV["APIFY_API_KEY"] = "test-apify-key"

    response_body = [
      {
        "caption" => "Test Recipe\n\nIngredients:\n- 1 cup flour\n\nInstructions:\n- Mix",
        "displayUrl" => "https://cdn.example.com/cover.jpg"
      }
    ]

    stub_request(:post, "https://api.apify.com/v2/acts/apify~instagram-reel-scraper/run-sync-get-dataset-items")
      .with(
        query: { "token" => "test-apify-key" },
        headers: { "Content-Type" => "application/json" },
        body: { username: [ url ], resultsLimit: 1 }.to_json
      )
      .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })

    stub_llm_response(name: "Test Recipe", ingredients: [ "1 cup flour" ], instructions: [ "Mix" ])

    result = RecipeImporter.new(url).import

    assert result.success?
    assert_equal "Test Recipe", result.recipe_attributes[:name]
    assert_equal "https://cdn.example.com/cover.jpg", result.cover_image_url
  ensure
    ENV["APIFY_API_KEY"] = previous_key
  end

  test "returns error when instagram caption is missing" do
    url = "https://www.instagram.com/reel/DRUf_pBiPdh/"
    previous_key = ENV["APIFY_API_KEY"]
    ENV["APIFY_API_KEY"] = "test-apify-key"

    response_body = [
      {
        "caption" => " ",
        "displayUrl" => "https://cdn.example.com/cover.jpg"
      }
    ]

    stub_request(:post, "https://api.apify.com/v2/acts/apify~instagram-reel-scraper/run-sync-get-dataset-items")
      .with(
        query: { "token" => "test-apify-key" },
        headers: { "Content-Type" => "application/json" },
        body: { username: [ url ], resultsLimit: 1 }.to_json
      )
      .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })

    result = RecipeImporter.new(url).import

    assert_not result.success?
    assert_equal :instagram_no_caption, result.error_code
  ensure
    ENV["APIFY_API_KEY"] = previous_key
  end

  test "returns error when apify key is missing for instagram" do
    url = "https://www.instagram.com/p/DRUf_pBiPdh/"
    previous_key = ENV["APIFY_API_KEY"]
    ENV.delete("APIFY_API_KEY")

    Rails.application.credentials.stub(:dig, nil) do
      result = RecipeImporter.new(url).import

      assert_not result.success?
      assert_equal :apify_missing_token, result.error_code
    end
  ensure
    ENV["APIFY_API_KEY"] = previous_key
  end

  test "returns error when no extraction method succeeds" do
    html = "<html><body><h1>Just a regular page</h1></body></html>"

    stub_request(:get, "https://example.com/page")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    # LLM fallback returns empty name = no recipe found
    stub_llm_no_recipe_found

    result = RecipeImporter.new("https://example.com/page").import

    assert_not result.success?
    assert_match(/could not extract recipe/i, result.error)
    assert_equal :no_recipe_found, result.error_code
  end

  # ===================
  # HTTP HEADERS TESTS
  # ===================

  test "sends appropriate headers when fetching" do
    stub_request(:get, "https://example.com/recipe")
      .with(
        headers: {
          "User-Agent" => "Mozilla/5.0 (compatible; Hauptgang Recipe Importer)",
          "Accept" => "text/html"
        }
      )
      .to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" })

    RecipeImporter.new("https://example.com/recipe").import

    assert_requested :get, "https://example.com/recipe"
  end

  # ===================
  # DEPENDENCY INJECTION TESTS
  # ===================

  test "accepts injected http_client for testability" do
    mock_client = Minitest::Mock.new
    # Use Struct instead of OpenStruct - it's built-in and doesn't need require
    FakeResponse = Struct.new(:success, :headers, :body, keyword_init: true) do
      alias_method :success?, :success
    end
    mock_response = FakeResponse.new(
      success: true,
      headers: { "content-type" => "text/html" },
      body: '<html><head><script type="application/ld+json">{"@type":"Recipe","name":"Injected"}</script></head></html>'
    )
    mock_client.expect(:get, mock_response, [ "https://example.com/recipe" ])

    result = RecipeImporter.new("https://example.com/recipe", http_client: mock_client).import

    assert result.success?
    assert_equal "Injected", result.recipe_attributes[:name]
    mock_client.verify
  end
end
