require "test_helper"

class RecipeContentImportJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @recipe = recipes(:one)
    @recipe.update!(import_status: :pending, name: "Placeholder")
  end

  test "skips cover image download when cover_image_url points to private host" do
    result = success_result(cover_image_url: "http://127.0.0.1/cover.jpg")
    job = RecipeContentImportJob.new

    job.stub(:extract_from_content, result) do
      job.perform(@user.id, @recipe.id, "https://example.com/recipe", [ "{\"@type\":\"Recipe\"}" ], "<body>Recipe</body>", {})
    end

    assert_not_requested(:get, "http://127.0.0.1/cover.jpg")

    @recipe.reload
    assert_equal :completed, @recipe.import_status.to_sym
    assert_equal "Imported Recipe", @recipe.name
    assert_not @recipe.cover_image.attached?
  end

  test "downloads and attaches cover image for public URL" do
    public_image_url = "https://example.com/cover.jpg"
    result = success_result(cover_image_url: public_image_url)
    job = RecipeContentImportJob.new

    stub_request(:get, public_image_url)
      .to_return(status: 200, body: "fake-image-bytes", headers: { "Content-Type" => "image/jpeg" })

    job.stub(:extract_from_content, result) do
      job.perform(@user.id, @recipe.id, "https://example.com/recipe", [ "{\"@type\":\"Recipe\"}" ], "<body>Recipe</body>", {})
    end

    assert_requested(:get, public_image_url, times: 1)

    @recipe.reload
    assert_equal :completed, @recipe.import_status.to_sym
    assert @recipe.cover_image.attached?
  end

  test "uses og:image as fallback when extractor has no cover image URL" do
    og_image_url = "https://example.com/og-cover.jpg"
    result = success_result(cover_image_url: nil)
    job = RecipeContentImportJob.new

    stub_request(:get, og_image_url)
      .to_return(status: 200, body: "fake-image-bytes", headers: { "Content-Type" => "image/jpeg" })

    job.stub(:extract_from_content, result) do
      job.perform(
        @user.id,
        @recipe.id,
        "https://example.com/recipe",
        [ "{\"@type\":\"Recipe\"}" ],
        "<body>Recipe</body>",
        { "og:image" => og_image_url }
      )
    end

    assert_requested(:get, og_image_url, times: 1)

    @recipe.reload
    assert_equal :completed, @recipe.import_status.to_sym
    assert @recipe.cover_image.attached?
  end

  test "uses DOM cover image candidates when extractor and meta image are missing" do
    dom_image_url = "https://example.com/dom-cover.jpg"
    result = success_result(cover_image_url: nil)
    job = RecipeContentImportJob.new

    stub_request(:get, dom_image_url)
      .to_return(status: 200, body: "fake-image-bytes", headers: { "Content-Type" => "image/jpeg" })

    job.stub(:extract_from_content, result) do
      job.perform(
        @user.id,
        @recipe.id,
        "https://example.com/recipe",
        [ "{\"@type\":\"Recipe\"}" ],
        "<body>Recipe</body>",
        {},
        [ dom_image_url ]
      )
    end

    assert_requested(:get, dom_image_url, times: 1)

    @recipe.reload
    assert_equal :completed, @recipe.import_status.to_sym
    assert @recipe.cover_image.attached?
  end

  test "tries next DOM cover image candidate when first one fails" do
    first_candidate = "http://127.0.0.1/private.jpg"
    second_candidate = "https://example.com/dom-cover.jpg"
    result = success_result(cover_image_url: nil)
    job = RecipeContentImportJob.new

    stub_request(:get, second_candidate)
      .to_return(status: 200, body: "fake-image-bytes", headers: { "Content-Type" => "image/jpeg" })

    job.stub(:extract_from_content, result) do
      job.perform(
        @user.id,
        @recipe.id,
        "https://example.com/recipe",
        [ "{\"@type\":\"Recipe\"}" ],
        "<body>Recipe</body>",
        {},
        [ first_candidate, second_candidate ]
      )
    end

    assert_not_requested(:get, first_candidate)
    assert_requested(:get, second_candidate, times: 1)

    @recipe.reload
    assert_equal :completed, @recipe.import_status.to_sym
    assert @recipe.cover_image.attached?
  end

  test "marks recipe as failed when extraction fails" do
    result = RecipeImporter::Result.new(
      success?: false,
      recipe_attributes: {},
      cover_image_url: nil,
      error: "No recipe found",
      error_code: :no_recipe_found
    )
    job = RecipeContentImportJob.new

    job.stub(:extract_from_content, result) do
      job.perform(@user.id, @recipe.id, "https://example.com/recipe", [ "{\"@type\":\"Recipe\"}" ], "<body>Recipe</body>", {})
    end

    @recipe.reload
    assert_equal :failed, @recipe.import_status.to_sym
    assert_equal "Import from example.com failed.", @recipe.error_message
  end

  private

  def success_result(cover_image_url:)
    RecipeImporter::Result.new(
      success?: true,
      recipe_attributes: { name: "Imported Recipe", ingredients: [ "1 cup flour" ], instructions: [ "Mix" ] },
      cover_image_url: cover_image_url,
      error: nil,
      error_code: nil
    )
  end
end
