require "faraday"
require "faraday/follow_redirects"
require "json"
require "nokogiri"
require "yaml"
require "fileutils"

CORPUS_DIR = Rails.root.join("test/recipe_corpus")
MANIFEST_PATH = CORPUS_DIR.join("manifest.yml")
SNAPSHOTS_DIR = CORPUS_DIR.join("snapshots/static")

namespace :recipe_corpus do
  desc "Fetch HTML snapshots for all URLs in the corpus manifest"
  task fetch: :environment do
    manifest = load_manifest
    force = ENV["FORCE"] == "1"
    target_url = ENV["URL"]

    entries = if target_url
      manifest.select { |e| e["url"] == target_url }.tap do |found|
        abort "URL not found in manifest: #{target_url}" if found.empty?
      end
    else
      manifest
    end

    fetched = 0
    skipped = 0
    failed = 0

    entries.each do |entry|
      result = fetch_snapshot_for_entry(entry, force: force)
      fetched += 1 if result == :fetched
      skipped += 1 if result == :skipped
      failed += 1 if result == :failed

      sleep 1 # be polite
    end

    puts "\nDone: fetched=#{fetched} skipped=#{skipped} failed=#{failed} total=#{entries.size}"
  end

  desc "Add a URL to the corpus manifest and fetch its snapshot"
  task add: :environment do
    url = ENV["URL"] || abort("Usage: bin/rails recipe_corpus:add URL=https://...")
    slug = url_to_slug(url)

    manifest = load_manifest

    if manifest.any? { |e| e["slug"] == slug }
      abort "Slug '#{slug}' already exists in manifest"
    end

    if manifest.any? { |e| e["url"] == url }
      abort "URL already exists in manifest"
    end

    domain = URI.parse(url).host.sub(/\Awww\./, "")
    base_entry = {
      "url" => url,
      "domain" => domain,
      "slug" => slug,
      "tags" => {
        "structured_data" => "unknown",
        "js_required" => false
      },
      "expected" => {
        "result" => "fail",
        "extractor" => nil,
        "min_ingredients" => nil,
        "min_instructions" => nil
      }
    }

    fetch_snapshot_for_entry(base_entry, force: true)
    inferred = infer_bot_protection_from_snapshot(slug)
    entry = base_entry.deep_dup
    entry["tags"]["bot_protected"] = inferred[:bot_protected]

    manifest << entry
    File.write(MANIFEST_PATH, manifest.to_yaml)
    puts "Added #{slug} to manifest"
    puts "  bot_protected: #{inferred[:bot_protected]} (#{inferred[:reason]})"

    if entry["tags"]["bot_protected"] && inferred[:bot_evidence].any?
      puts "  evidence: #{inferred[:bot_evidence].join(', ')}"
    end
  end

  desc "Inspect one corpus entry by slug (snapshot metadata + extractor output)"
  task inspect: :environment do
    slug = ENV["SLUG"] || abort("Usage: bin/rails recipe_corpus:inspect SLUG=chefkoch-gyros [LLM=1]")
    skip_llm = !ENV.key?("LLM") || ENV["LLM"] != "1"
    manifest = load_manifest
    entry = manifest.find { |item| item["slug"] == slug }
    abort "Slug not found in manifest: #{slug}" unless entry

    html_path = SNAPSHOTS_DIR.join("#{slug}.html")
    meta_path = SNAPSHOTS_DIR.join("#{slug}.meta.yml")

    print_inspect_section("Entry")
    print_inspect_kv(
      "slug" => entry["slug"],
      "url" => entry["url"],
      "domain" => entry["domain"]
    )
    puts "  tags:"
    (entry["tags"] || {}).each do |key, value|
      puts "    - #{key}: #{value}"
    end

    unless html_path.exist? && html_path.size > 0
      print_inspect_section("Snapshot")
      puts "  missing_or_empty: true"
      puts "  html_path: #{html_path}"
      puts "  suggestion: bin/rails recipe_corpus:fetch URL=#{entry["url"]}"
      next
    end

    meta = meta_path.exist? ? (YAML.load_file(meta_path) || {}) : {}
    print_inspect_section("Snapshot")
    print_inspect_kv(
      "html_path" => html_path,
      "meta_path" => meta_path,
      "html_size" => "#{html_path.size} bytes",
      "fetched_at" => meta["fetched_at"] || "n/a",
      "http_status" => meta["http_status"] || "n/a",
      "content_type" => meta["content_type"] || "n/a"
    )

    headers = meta["response_headers"] || {}
    if headers.any?
      print_inspect_section("Response Headers")
      headers.each { |key, value| puts "  #{key}: #{value}" }
    end

    html = File.read(html_path)
    inferred = infer_bot_protection(meta: meta, html: html)
    print_inspect_section("Bot Protection Inference")
    print_inspect_kv(
      "bot_protected" => inferred[:bot_protected],
      "reason" => inferred[:reason]
    )
    if inferred[:bot_evidence].any?
      puts "  evidence:"
      inferred[:bot_evidence].each { |item| puts "    - #{item}" }
    end

    if meta["http_status"] && meta["http_status"] != 200
      print_inspect_section("Extraction")
      puts "  skipped: true"
      puts "  reason: http_status=#{meta["http_status"]}"
      next
    end

    extraction = try_extract(html, entry["url"], skip_llm: skip_llm)
    print_inspect_section("Extraction")
    print_inspect_kv(
      "llm" => (skip_llm ? "skipped" : "included"),
      "success" => extraction[:success],
      "extractor" => extraction[:extractor] || "none",
      "elapsed" => "#{format('%.2f', extraction[:elapsed])}s"
    )
    puts "  error: #{extraction[:error]}" if extraction[:error]
    if extraction[:success]
      print_inspect_kv(
        "name" => extraction[:name],
        "ingredients_count" => extraction[:ingredients_count],
        "instructions_count" => extraction[:instructions_count]
      )
      recipe_result = if extraction[:extractor] == "json_ld"
        RecipeImporters::JsonLdExtractor.new(html, entry["url"]).extract
      elsif extraction[:extractor] == "llm"
        RecipeImporters::LlmExtractor.new(html, entry["url"]).extract
      end

      recipe_attributes = recipe_result&.recipe_attributes || {}
      ingredients = Array(recipe_attributes[:ingredients]).compact
      instructions = Array(recipe_attributes[:instructions]).compact

      print_inspect_section("Ingredients")
      if ingredients.any?
        ingredients.each { |ingredient| puts "  - #{ingredient}" }
      else
        puts "  (none)"
      end

      print_inspect_section("Instructions")
      if instructions.any?
        instructions.each_with_index do |instruction, index|
          puts "  #{index + 1}. #{instruction}"
        end
      else
        puts "  (none)"
      end

      if extraction[:extractor] == "json_ld"
        raw_blocks = extract_recipe_json_ld_blocks(html)
        print_inspect_section("Raw JSON-LD")
        if raw_blocks.any?
          raw_blocks.each_with_index do |raw_block, index|
            puts "  -- block #{index + 1} --"
            puts indent_block(JSON.pretty_generate(raw_block[:data]), 4)
          end
        else
          puts "  (no recipe JSON-LD blocks found)"
        end
      end
    end
  end

  desc "Re-fetch all snapshots (refresh)"
  task refresh: :environment do
    ENV["FORCE"] = "1"
    Rake::Task["recipe_corpus:fetch"].invoke
  end

  desc "Evaluate the corpus: run extraction on all snapshots and report results"
  task evaluate: :environment do
    skip_llm = !ENV.key?("LLM") || ENV["LLM"] != "1"
    manifest = load_manifest

    results = []

    manifest.each do |entry|
      slug = entry["slug"]
      html_path = SNAPSHOTS_DIR.join("#{slug}.html")
      meta_path = SNAPSHOTS_DIR.join("#{slug}.meta.yml")

      unless html_path.exist? && html_path.size > 0
        results << build_result(entry, success: false, extractor: nil, error: "no snapshot")
        next
      end

      meta = meta_path.exist? ? YAML.load_file(meta_path) : {}
      http_status = meta["http_status"]

      if http_status && http_status != 200
        results << build_result(entry, success: false, extractor: nil, error: "HTTP #{http_status}")
        next
      end

      html = File.read(html_path)
      url = entry["url"]

      extraction = try_extract(html, url, skip_llm: skip_llm)
      results << build_result(entry, **extraction)
    end

    expectation_failures = print_report(results, skip_llm: skip_llm)
    next if expectation_failures.empty?

    abort "Evaluation failed: #{expectation_failures.size} URL(s) did not match expected corpus contract"
  end
end

def print_inspect_section(title)
  puts ""
  puts "─" * 72
  puts title
  puts "─" * 72
end

def print_inspect_kv(fields)
  fields.each do |key, value|
    puts "  #{key.to_s.ljust(18)} #{value}"
  end
end

def indent_block(text, spaces = 2)
  prefix = " " * spaces
  text.lines.map { |line| "#{prefix}#{line}" }.join
end

def load_manifest
  abort "Manifest not found: #{MANIFEST_PATH}" unless MANIFEST_PATH.exist?
  YAML.load_file(MANIFEST_PATH) || []
end

def corpus_http_client
  @corpus_http_client ||= Faraday.new do |conn|
    conn.options.timeout = 15
    conn.options.open_timeout = 10
    conn.headers["User-Agent"] = "Mozilla/5.0 (compatible; Hauptgang Recipe Importer)"
    conn.headers["Accept"] = "text/html"
    conn.response :follow_redirects, limit: 5
  end
end

def extract_relevant_headers(headers)
  keys = %w[
    server
    content-type
    content-length
    x-powered-by
    cf-ray
    cf-cache-status
    cf-mitigated
    x-datadome
    x-akamai-session-info
    x-iinfo
    set-cookie
  ]
  headers.to_h.slice(*keys)
end

def fetch_snapshot_for_entry(entry, force: false)
  slug = entry["slug"]
  html_path = SNAPSHOTS_DIR.join("#{slug}.html")
  meta_path = SNAPSHOTS_DIR.join("#{slug}.meta.yml")

  if html_path.exist? && !force
    puts "  skip  #{slug} (exists, use FORCE=1 to overwrite)"
    return :skipped
  end

  print "  fetch #{slug} ... "

  begin
    response = corpus_http_client.get(entry["url"])

    File.binwrite(html_path, response.body)
    File.write(meta_path, {
      "fetched_at" => Time.now.utc.iso8601,
      "http_status" => response.status,
      "content_type" => response.headers["content-type"].to_s,
      "content_length" => response.body.bytesize,
      "response_headers" => extract_relevant_headers(response.headers)
    }.to_yaml)

    puts "#{response.status} (#{response.body.bytesize} bytes)"
    :fetched
  rescue Faraday::Error, URI::InvalidURIError => error
    File.write(html_path, "")
    File.write(meta_path, {
      "fetched_at" => Time.now.utc.iso8601,
      "http_status" => nil,
      "error" => "#{error.class}: #{error.message}",
      "content_type" => nil,
      "content_length" => 0
    }.to_yaml)

    puts "FAILED (#{error.class})"
    :failed
  end
end

def infer_bot_protection_from_snapshot(slug)
  html_path = SNAPSHOTS_DIR.join("#{slug}.html")
  meta_path = SNAPSHOTS_DIR.join("#{slug}.meta.yml")

  html = html_path.exist? ? File.read(html_path) : ""
  meta = meta_path.exist? ? (YAML.load_file(meta_path) || {}) : {}

  infer_bot_protection(meta: meta, html: html)
end

def infer_bot_protection(meta:, html:)
  headers = (meta["response_headers"] || {}).transform_keys { |k| k.to_s.downcase }
  header_blob = headers.map { |key, value| "#{key}:#{value}" }.join("\n").downcase
  body = html.to_s.downcase
  status = meta["http_status"].to_i if meta["http_status"]

  provider_context = []
  provider_context << "cf-ray" if headers["cf-ray"].to_s != ""
  provider_context << "cloudflare-server" if headers["server"].to_s.downcase.include?("cloudflare")
  provider_context << "akamai-server" if header_blob.match?(/akamai|x-akamai|x-iinfo/)
  provider_context << "incapsula" if header_blob.match?(/incap|imperva/)

  anti_bot_headers = []
  anti_bot_headers << "cf-mitigated" if headers["cf-mitigated"].to_s != ""
  anti_bot_headers << "datadome-header" if header_blob.include?("datadome")
  anti_bot_headers << "perimeterx-header" if header_blob.match?(/perimeterx|px-/)
  anti_bot_headers << "cf-bm-cookie" if header_blob.include?("__cf_bm")

  challenge_markers = []
  {
    "captcha" => /captcha/,
    "verify-you-are-human" => /verify\s+you\s+are\s+human/,
    "attention-required" => /attention\s+required/,
    "cf-challenge" => /cf[-\s]?challenge|challenge-platform/,
    "access-denied" => /access\s+denied/,
    "bot-protection" => /bot\s+protection|automated\s+access/
  }.each do |name, regex|
    challenge_markers << name if body.match?(regex)
  end

  not_found_markers = body.match?(/not\s+found|page\s+not\s+found|404|doesn'?t\s+exist|unavailable/)

  gate_a = [403, 429].include?(status) || (status == 503 && challenge_markers.any?) || challenge_markers.any?
  gate_b = anti_bot_headers.any? || challenge_markers.any?
  very_strong_body = challenge_markers.intersect?(%w[captcha verify-you-are-human attention-required cf-challenge])

  if [404, 410].include?(status) && not_found_markers && !challenge_markers.any?
    return {
      bot_protected: false,
      reason: "status #{status} with not-found body and no challenge markers",
      provider_context: provider_context,
      bot_evidence: []
    }
  end

  classified = (gate_a && gate_b) || very_strong_body
  evidence = (anti_bot_headers + challenge_markers).uniq
  reason = if classified
    "anti-bot challenge detected (status=#{status || 'n/a'})"
  elsif provider_context.any?
    "provider context only (#{provider_context.join(', ')})"
  else
    "no anti-bot challenge evidence"
  end

  {
    bot_protected: classified,
    reason: reason,
    provider_context: provider_context,
    bot_evidence: evidence
  }
end

def url_to_slug(url)
  uri = URI.parse(url)
  domain = uri.host.sub(/\Awww\./, "").split(".").first
  path = uri.path.gsub(%r{[^a-z0-9]+}i, "-").gsub(/\A-|-\z/, "")
  "#{domain}-#{path}".first(80)
end

def try_extract(html, url, skip_llm: true)
  start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  errors = []

  # Try JSON-LD
  result = RecipeImporters::JsonLdExtractor.new(html, url).extract
  if result.success?
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    return { success: true, extractor: "json_ld", name: result.recipe_attributes[:name],
             ingredients_count: result.recipe_attributes[:ingredients]&.length || 0,
             instructions_count: result.recipe_attributes[:instructions]&.length || 0,
             elapsed: elapsed, error: nil }
  end
  errors << "json_ld: #{result.error}"

  # Future: try microdata, rdfa extractors here

  # Try LLM (unless skipped)
  unless skip_llm
    result = RecipeImporters::LlmExtractor.new(html, url).extract
    if result.success?
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      return { success: true, extractor: "llm", name: result.recipe_attributes[:name],
               ingredients_count: result.recipe_attributes[:ingredients]&.length || 0,
               instructions_count: result.recipe_attributes[:instructions]&.length || 0,
               elapsed: elapsed, error: nil }
    end
    errors << "llm: #{result.error}"
  end

  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
  { success: false, extractor: nil, name: nil, ingredients_count: 0, instructions_count: 0,
    elapsed: elapsed, error: errors.join(" | ") }
end

def build_result(entry, success:, extractor:, error: nil, name: nil,
                 ingredients_count: 0, instructions_count: 0, elapsed: 0)
  {
    slug: entry["slug"],
    domain: entry["domain"],
    url: entry["url"],
    tags: entry["tags"] || {},
    expected: entry["expected"] || {},
    success: success,
    extractor: extractor,
    name: name,
    ingredients_count: ingredients_count,
    instructions_count: instructions_count,
    elapsed: elapsed,
    error: error
  }
end

def print_report(results, skip_llm: false)
  total = results.size
  successful = results.count { |r| r[:success] }
  expectation_failures = results.filter_map { |r| evaluate_expected_contract(r) }

  puts ""
  puts "═" * 56
  puts "  Recipe Import Corpus Evaluation"
  puts "═" * 56
  puts ""
  puts "Overall: #{successful}/#{total} successful (#{pct(successful, total)})"
  puts "(LLM #{skip_llm ? 'skipped — run with LLM=1 to include' : 'included'})"
  puts ""

  # By extractor
  extractor_counts = results.group_by { |r| r[:extractor] || "none" }
  puts "By extractor:"
  extractor_counts.sort_by { |k, _| k }.each do |ext, group|
    count = group.count { |r| r[:success] }
    puts "  #{ext.ljust(18)} #{count}/#{total} (#{pct(count, total)})"
  end
  puts ""

  # By domain
  domain_groups = results.group_by { |r| r[:domain] }
  puts "By domain:"
  domain_groups.sort_by { |k, _| k }.each do |domain, group|
    s = group.count { |r| r[:success] }
    t = group.size
    tags = group.flat_map { |r| tag_labels(r[:tags]) }.uniq
    status = if s == t
      "✓"
    elsif s == 0
      "✗"
    else
      "△"
    end
    tag_str = tags.any? ? "  (#{tags.join(', ')})" : ""
    puts "  #{domain.ljust(28)} #{s}/#{t}  #{status}#{tag_str}"
  end
  puts ""

  # By tag
  puts "By tag:"
  %w[bot_protected js_required].each do |tag|
    tagged = results.select { |r| r[:tags][tag] == true }
    next if tagged.empty?

    s = tagged.count { |r| r[:success] }
    t = tagged.size
    puts "  #{tag}: true".ljust(30) + "#{s}/#{t} (#{pct(s, t)})"
  end

  sd_groups = results.group_by { |r| r[:tags]["structured_data"] || "unknown" }
  sd_groups.each do |sd_type, group|
    s = group.count { |r| r[:success] }
    t = group.size
    puts "  structured_data: #{sd_type}".ljust(30) + "#{s}/#{t} (#{pct(s, t)})"
  end
  puts ""

  # Contract checks
  contract_passed = total - expectation_failures.size
  puts "Contract checks: #{contract_passed}/#{total} passed (#{pct(contract_passed, total)})"
  puts ""

  # Failed URLs (contract failures)
  if expectation_failures.any?
    puts "Failed URLs:"
    expectation_failures.each do |failure|
      r = failure[:result]
      tags = tag_labels(r[:tags])
      tag_str = tags.any? ? " (#{tags.join(', ')})" : ""
      puts "  ✗ #{r[:slug].ljust(45)} — #{failure[:reason]}#{tag_str}"
    end
    puts ""
  end

  puts "═" * 56
  expectation_failures
end

def pct(count, total)
  return "0.0%" if total.zero?

  "#{'%.1f' % (count.to_f / total * 100)}%"
end

def tag_labels(tags)
  labels = []
  labels << "bot_protected" if tags["bot_protected"]
  labels << "js_required" if tags["js_required"]
  labels << "no_structured_data" if tags["structured_data"] == "none"
  labels
end

def evaluate_expected_contract(result)
  expected = result[:expected] || {}
  expected_result = expected["result"] || "fail"

  case expected_result
  when "success"
    unless result[:success]
      return {
        result: result,
        reason: "expected success, got failure (#{result[:error] || 'unknown error'})"
      }
    end

    expected_extractor = expected["extractor"]
    if expected_extractor && result[:extractor] != expected_extractor
      return {
        result: result,
        reason: "expected extractor #{expected_extractor}, got #{result[:extractor] || 'none'}"
      }
    end

    min_ingredients = expected["min_ingredients"]
    if min_ingredients && result[:ingredients_count] < min_ingredients
      return {
        result: result,
        reason: "expected >= #{min_ingredients} ingredients, got #{result[:ingredients_count]}"
      }
    end

    min_instructions = expected["min_instructions"]
    if min_instructions && result[:instructions_count] < min_instructions
      return {
        result: result,
        reason: "expected >= #{min_instructions} instructions, got #{result[:instructions_count]}"
      }
    end
  when "fail"
    if result[:success]
      return {
        result: result,
        reason: "expected fail, but extracted successfully via #{result[:extractor]}"
      }
    end
  else
    return {
      result: result,
      reason: "invalid expected.result value '#{expected_result}'"
    }
  end

  nil
end

def extract_recipe_json_ld_blocks(html)
  doc = Nokogiri::HTML(html)
  scripts = doc.css('script[type="application/ld+json"]')

  scripts.filter_map do |script|
    raw = script.text.to_s.strip
    next if raw.empty?

    data = begin
      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end
    next unless data
    next unless json_ld_contains_recipe?(data)

    { raw: raw, data: data }
  end
end

def json_ld_contains_recipe?(data)
  case data
  when Array
    data.any? { |item| json_ld_contains_recipe?(item) }
  when Hash
    type = data["@type"]
    types = type.is_a?(Array) ? type : [ type ]
    return true if types.compact.any? { |value| value == "Recipe" || value.to_s.match?(%r{\Ahttps?://schema\.org/Recipe\z}) }

    %w[mainEntity mainEntityOfPage].any? { |key| json_ld_contains_recipe?(data[key]) } ||
      json_ld_contains_recipe?(data["@graph"])
  else
    false
  end
end
