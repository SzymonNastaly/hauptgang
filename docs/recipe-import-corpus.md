# Recipe Import Corpus

A regression testing and evaluation harness for the recipe import pipeline. Uses cached HTML snapshots of real recipe websites to test extractors without hitting live URLs.

## Key Concepts

- **Manifest** (`test/recipe_corpus/manifest.yml`): YAML list of URLs with metadata (domain, tags, expected results)
- **Snapshots** (`test/recipe_corpus/snapshots/static/`): Cached HTML files fetched from real URLs, gitignored, regenerated via rake task
- **CI tests** (`test/services/recipe_corpus_test.rb`): Only run against entries with `expected.result: success`, assert fuzzy plausibility (name present, minimum ingredient/instruction counts)
- **Evaluation report** (`bin/rails recipe_corpus:evaluate`): Runs all entries and validates each against its `expected.*` contract (pass/fail), while also printing grouped metrics

## Commands

```bash
bin/rails recipe_corpus:fetch              # Download HTML snapshots for all manifest URLs
bin/rails recipe_corpus:fetch URL=...      # Fetch a single URL's snapshot
bin/rails recipe_corpus:evaluate           # Run extraction on snapshots + enforce expected contracts (no LLM)
bin/rails recipe_corpus:evaluate LLM=1     # Include LLM extractor in evaluation (costs money)
bin/rails recipe_corpus:add URL=...        # Add URL + fetch snapshot + infer bot_protected
bin/rails recipe_corpus:inspect SLUG=...   # Inspect one slug's snapshot/metadata/extractor result
bin/rails recipe_corpus:refresh            # Re-fetch all snapshots (overwrites existing)
```

## Manifest Format

Each entry in `test/recipe_corpus/manifest.yml`:

```yaml
- url: "https://www.example.com/recipe/chocolate-cake"
  domain: example.com
  slug: example-chocolate-cake              # unique ID, becomes snapshot filename
  tags:
    structured_data: json_ld                # json_ld | microdata | rdfa | none | unknown
    js_required: false                      # needs headless browser to render
    bot_protected: false                    # behind Cloudflare/Datadome/etc.
  expected:
    result: success                         # success = tested in CI, fail = evaluation only
    extractor: json_ld                      # which extractor should handle this
    min_ingredients: 5                      # fuzzy assertion (null = skip check)
    min_instructions: 3                     # fuzzy assertion (null = skip check)
```

## How Tests Work

- Corpus tests are **local-only** — they are skipped in CI because snapshots are gitignored and too large to commit (expected to grow to 200+ MB)
- Only entries with `expected.result: success` become test cases
- Tests run extractors directly on cached HTML (no HTTP fetch, no URL validation)
- LLM extractor is **not called** — only deterministic extractors (JSON-LD, future microdata/RDFa)
- Assertions are fuzzy: recipe name is present, ingredient count ≥ minimum, instruction count ≥ minimum
- Missing snapshots **fail the test** locally (run `bin/rails recipe_corpus:fetch` to fix)
- Use `bin/rails recipe_corpus:evaluate` for a richer regression report

## How Evaluation Works

- Runs **all** manifest entries through extraction on cached snapshots
- Checks each URL against its `expected` contract:
  - `expected.result: success` => extraction must succeed, and optional `extractor`/minimum counts must match
  - `expected.result: fail` => contract passes if extraction fails, or if extraction succeeds but misses configured `min_ingredients` / `min_instructions`
- Prints report grouped by: overall, extractor, domain, tags
- Lists contract failures under `Failed URLs`
- Exits non-zero if any URL violates its expected contract
- LLM is skipped by default (run with `LLM=1` to include, costs money)

## Workflow: Adding a New URL

1. `bin/rails recipe_corpus:add URL=https://...`
   - Adds to manifest with conservative defaults (`expected.result: fail`)
   - Infers `tags.bot_protected` from response metadata/body using conservative anti-bot heuristics
   - Cloudflare presence alone is not enough (Cloudflare-backed 404 pages remain `bot_protected: false`)
   - Explicit challenge indicators (captcha / "verify you are human") can set `bot_protected: true`
   - Fetches the HTML snapshot
2. `bin/rails recipe_corpus:evaluate` — check if extraction succeeded
3. If it works, edit `manifest.yml`: set `expected.result: success`, fill in `min_ingredients`/`min_instructions`, set correct `structured_data` tag
4. `bin/rails test test/services/recipe_corpus_test.rb` — verify it passes in CI

## Inspect a Single URL by Slug

- `bin/rails recipe_corpus:inspect SLUG=chefkoch-gyros`
- Shows manifest metadata, snapshot file paths/sizes, HTTP status/headers, bot-protection inference, and extractor result
- If extraction succeeds via JSON-LD, also prints the matching raw JSON-LD block(s)
- Add `LLM=1` to include LLM in extraction attempt

## Workflow: After Improving an Extractor

1. `bin/rails recipe_corpus:evaluate` — compare before/after success rates
2. Any newly successful URLs: update their `expected.result` to `success` in manifest
3. Run CI tests to confirm no regressions

## Snapshots

- Stored in `test/recipe_corpus/snapshots/static/` (gitignored)
- Each URL has `{slug}.html` (raw HTML body) and `{slug}.meta.yml` (HTTP status, content-type, headers, fetch timestamp)
- Regenerate all with `bin/rails recipe_corpus:fetch` (skips existing) or `recipe_corpus:refresh` (overwrites all)
- Directory structure supports future fetch strategies: `snapshots/rendered/` (headless browser), `snapshots/antibot/` (anti-bot bypass)

## File Locations


| File                                             | Purpose                                        |
| ------------------------------------------------ | ---------------------------------------------- |
| `test/recipe_corpus/manifest.yml`                | URL list with metadata and expected results    |
| `test/recipe_corpus/snapshots/static/*.html`     | Cached HTML (gitignored)                       |
| `test/recipe_corpus/snapshots/static/*.meta.yml` | Response metadata (gitignored)                 |
| `lib/tasks/recipe_corpus.rake`                   | All rake tasks (fetch, evaluate, add, refresh) |
| `test/services/recipe_corpus_test.rb`            | CI regression tests                            |


## Evaluation Report Details

Failed URLs in the report show why a URL violated its expected contract. Typical reasons:
- `expected success, got failure (...)` — extraction failed for a URL marked as expected success
- `expected fail, but extracted successfully ...` — URL marked as expected fail now extracts successfully
- `expected >= N ingredients/instructions` — extraction succeeded but falls below configured thresholds
- `expected extractor X, got Y` — extraction succeeded with a different extractor than expected

