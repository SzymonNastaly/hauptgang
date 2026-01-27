module LlmStubHelper
  OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"

  # Stubs the OpenRouter API to return a response indicating no recipe was found
  def stub_llm_no_recipe_found
    stub_llm_response(name: "", ingredients: [], instructions: [])
  end

  # Stubs the OpenRouter API to return a successful recipe extraction
  def stub_llm_response(name:, ingredients:, instructions:, prep_time: nil, cook_time: nil, servings: nil, notes: nil)
    content = {
      "name" => name,
      "ingredients" => ingredients,
      "instructions" => instructions,
      "prep_time" => prep_time,
      "cook_time" => cook_time,
      "servings" => servings,
      "notes" => notes
    }.compact

    stub_openrouter_api(response_body: build_openrouter_response(content))
  end

  # Low-level stub for the OpenRouter API endpoint
  def stub_openrouter_api(response_body:, status: 200)
    stub_request(:post, OPENROUTER_ENDPOINT)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Builds the OpenRouter response JSON structure
  def build_openrouter_response(content)
    {
      "id" => "gen-test-123",
      "model" => "openai/gpt-oss-20b",
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => content.to_json
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => { "prompt_tokens" => 100, "completion_tokens" => 50 }
    }
  end
end
