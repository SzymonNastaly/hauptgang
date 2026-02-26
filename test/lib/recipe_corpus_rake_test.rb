require "test_helper"

load Rails.root.join("lib/tasks/recipe_corpus.rake")

class RecipeCorpusRakeTest < ActiveSupport::TestCase
  test "does not classify cloudflare-only 403 as bot challenge" do
    result = infer_bot_protection(
      meta: {
        "http_status" => 403,
        "response_headers" => {
          "server" => "cloudflare",
          "cf-ray" => "123abc"
        }
      },
      html: "<html><body>Forbidden</body></html>"
    )

    assert_not result[:bot_protected]
    assert_match(/provider context only/i, result[:reason])
  end

  test "classifies 403 with challenge body markers as bot protected" do
    result = infer_bot_protection(
      meta: {
        "http_status" => 403,
        "response_headers" => {
          "server" => "cloudflare",
          "cf-ray" => "123abc"
        }
      },
      html: "<html><body>Attention Required. Verify you are human.</body></html>"
    )

    assert result[:bot_protected]
    assert_includes result[:bot_evidence], "attention-required"
  end

  test "keeps cloudflare 404 not-found pages unclassified as bot protection" do
    result = infer_bot_protection(
      meta: {
        "http_status" => 404,
        "response_headers" => {
          "server" => "cloudflare",
          "cf-ray" => "123abc"
        }
      },
      html: "<html><body>404 page not found</body></html>"
    )

    assert_not result[:bot_protected]
    assert_match(/not-found body/i, result[:reason])
  end

  test "classifies explicit challenge body even on non-block status" do
    result = infer_bot_protection(
      meta: {
        "http_status" => 404,
        "response_headers" => {
          "server" => "cloudflare"
        }
      },
      html: "<html><body>Attention Required! Please complete the CAPTCHA challenge.</body></html>"
    )

    assert result[:bot_protected]
    assert_includes result[:bot_evidence], "captcha"
  end

  test "does not classify normal 200 recipe page as bot protected" do
    result = infer_bot_protection(
      meta: {
        "http_status" => 200,
        "response_headers" => {
          "content-type" => "text/html"
        }
      },
      html: "<html><head><title>Classic Guacamole</title></head><body>Ingredients and instructions</body></html>"
    )

    assert_not result[:bot_protected]
    assert_match(/no anti-bot challenge evidence/i, result[:reason])
  end

  test "expected success contract fails when extraction fails" do
    failure = evaluate_expected_contract(
      {
        slug: "demo",
        success: false,
        error: "HTTP 403",
        extractor: nil,
        ingredients_count: 0,
        instructions_count: 0,
        expected: { "result" => "success", "extractor" => "json_ld" }
      }
    )

    assert failure
    assert_match(/expected success/i, failure[:reason])
  end

  test "expected fail contract fails on unexpected success" do
    failure = evaluate_expected_contract(
      {
        slug: "demo",
        success: true,
        error: nil,
        extractor: "json_ld",
        ingredients_count: 10,
        instructions_count: 8,
        expected: { "result" => "fail" }
      }
    )

    assert failure
    assert_match(/expected fail/i, failure[:reason])
  end

  test "expected success contract enforces min ingredient count" do
    failure = evaluate_expected_contract(
      {
        slug: "demo",
        success: true,
        error: nil,
        extractor: "json_ld",
        ingredients_count: 3,
        instructions_count: 8,
        expected: { "result" => "success", "min_ingredients" => 5 }
      }
    )

    assert failure
    assert_match(/expected >= 5 ingredients/i, failure[:reason])
  end

  test "expected success contract passes when all checks match" do
    failure = evaluate_expected_contract(
      {
        slug: "demo",
        success: true,
        error: nil,
        extractor: "json_ld",
        ingredients_count: 7,
        instructions_count: 6,
        expected: {
          "result" => "success",
          "extractor" => "json_ld",
          "min_ingredients" => 5,
          "min_instructions" => 3
        }
      }
    )

    assert_nil failure
  end

end
