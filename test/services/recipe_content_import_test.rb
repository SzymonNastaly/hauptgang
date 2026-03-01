require "test_helper"
require "nokogiri"

class RecipeContentImportTest < ActiveSupport::TestCase
  CORPUS_DIR = Rails.root.join("test/recipe_corpus")
  MANIFEST_PATH = CORPUS_DIR.join("manifest.yml")
  SNAPSHOTS_DIR = CORPUS_DIR.join("snapshots/static")

  REMOVABLE_TAGS = %w[script style nav header footer aside svg iframe noscript].freeze

  manifest = if MANIFEST_PATH.exist?
    YAML.load_file(MANIFEST_PATH) || []
  else
    []
  end

  success_entries = manifest.select { |e| e.dig("expected", "result") == "success" }

  if ENV["CI"]
    test "content import corpus tests are local-only (snapshots are gitignored)" do
      skip "Corpus tests run locally only — snapshots are too large for CI. Run: bin/rails recipe_corpus:fetch"
    end
  elsif success_entries.empty?
    test "content import corpus has no success entries yet" do
      skip "No corpus entries marked as expected.result=success yet"
    end
  else
    success_entries.each do |entry|
      slug = entry["slug"]
      html_path = SNAPSHOTS_DIR.join("#{slug}.html")

      test "content import pipeline: #{slug}" do
        assert html_path.exist? && html_path.size > 0,
          "Missing snapshot for #{slug} — run: bin/rails recipe_corpus:fetch"

        html = File.read(html_path)

        # Simulate what PreprocessingScript.js would produce
        json_ld_strings = extract_json_ld_blocks(html)
        cleaned_html = clean_html(html)

        # Run the same extraction pipeline as RecipeContentImportJob
        result = extract_from_content(entry["url"], json_ld_strings, cleaned_html)

        assert result.success?, "Expected successful extraction for #{slug}, got: #{result.error}"
        assert result.recipe_attributes[:name].present?, "Recipe name should be present for #{slug}"

        min_ingredients = entry.dig("expected", "min_ingredients")
        if min_ingredients
          actual = result.recipe_attributes[:ingredients]&.length || 0
          assert actual >= min_ingredients,
            "Expected >= #{min_ingredients} ingredients for #{slug}, got #{actual}"
        end

        min_instructions = entry.dig("expected", "min_instructions")
        if min_instructions
          actual = result.recipe_attributes[:instructions]&.length || 0
          assert actual >= min_instructions,
            "Expected >= #{min_instructions} instructions for #{slug}, got #{actual}"
        end
      end
    end
  end

  private

  def extract_json_ld_blocks(html)
    doc = Nokogiri::HTML(html)
    doc.css('script[type="application/ld+json"]').map { |script| script.text.strip }.reject(&:blank?)
  end

  def clean_html(html)
    doc = Nokogiri::HTML(html)
    REMOVABLE_TAGS.each { |tag| doc.css(tag).remove }
    doc.css("*").each do |el|
      el.attributes.each_key do |attr_name|
        el.remove_attribute(attr_name) if attr_name.start_with?("data-") || attr_name == "srcset"
      end
    end
    doc.to_html
  end

  def extract_from_content(source_url, json_ld_strings, html)
    # Try JSON-LD first: parse provided blocks directly (no HTML reconstruction)
    if json_ld_strings.present?
      result = RecipeImporters::JsonLdExtractor.new("", source_url).extract_from_json_ld_strings(json_ld_strings)
      return result if result.success?
    end

    # Fall back to LLM extraction with cleaned HTML (only if LLM=1)
    if ENV["LLM"] == "1" && html.present?
      result = RecipeImporters::LlmExtractor.new(html, source_url).extract
      return result if result.success?
    end

    RecipeImporter::Result.new(
      success?: false,
      recipe_attributes: {},
      cover_image_url: nil,
      error: "Could not extract recipe from provided content",
      error_code: :no_recipe_found
    )
  end
end
