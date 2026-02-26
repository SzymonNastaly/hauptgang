require "test_helper"

class RecipeCorpusTest < ActiveSupport::TestCase
  CORPUS_DIR = Rails.root.join("test/recipe_corpus")
  MANIFEST_PATH = CORPUS_DIR.join("manifest.yml")
  SNAPSHOTS_DIR = CORPUS_DIR.join("snapshots/static")

  manifest = if MANIFEST_PATH.exist?
    YAML.load_file(MANIFEST_PATH) || []
  else
    []
  end

  success_entries = manifest.select { |e| e.dig("expected", "result") == "success" }

  if ENV["CI"]
    test "corpus tests are local-only (snapshots are gitignored)" do
      skip "Corpus tests run locally only — snapshots are too large for CI. Run: bin/rails recipe_corpus:fetch"
    end
  elsif success_entries.empty?
    test "corpus has no success entries yet (run evaluate to find working URLs)" do
      skip "No corpus entries marked as expected.result=success yet"
    end
  else
    success_entries.each do |entry|
      slug = entry["slug"]
      html_path = SNAPSHOTS_DIR.join("#{slug}.html")

      test "corpus: #{slug}" do
        assert html_path.exist? && html_path.size > 0,
          "Missing snapshot for #{slug} — run: bin/rails recipe_corpus:fetch"

        html = File.read(html_path)
        result = extract_from_cached_html(html, entry["url"])

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

  # Runs the extraction pipeline on cached HTML, bypassing HTTP fetch.
  # LLM is not called — corpus CI tests only cover deterministic extractors.
  def extract_from_cached_html(html, source_url)
    # Try JSON-LD (primary deterministic extractor)
    result = RecipeImporters::JsonLdExtractor.new(html, source_url).extract
    return result if result.success?

    # Future: try MicrodataExtractor, RdfaExtractor here

    # Return the last failure — LLM intentionally skipped in CI
    result
  end
end
