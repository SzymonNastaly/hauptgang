# iOS Share Extension Recipe Import (Safari)

This document explains how the iOS share extension sends Safari page data to the server for recipe import, what can fail, and how the fallback logic works.

## What Happens When User Shares from Safari

When the user shares a web page from Safari to `ImportRecipeExtension`, the client tries to send useful page data to the server instead of only sending the URL.

The client sends:
- `url`
- `jsonLd` (JSON-LD blocks)
- `metaTags`
- `html` (cleaned body HTML)

## Required iOS Setup

`Info.plist` for `ImportRecipeExtension` must include:
- `NSExtensionJavaScriptPreprocessingFile = PreprocessingScript`
- Activation rules for web page sharing

`PreprocessingScript.js` should use this JS entry style:
- `var Action = function() {};`
- `Action.prototype = { run: ..., finalize: ... }`
- `var ExtensionPreprocessingJS = new Action();`

This matches Apple's expected share-extension JavaScript format.

## How the Client Chooses What to Import

The extension tries these steps in order:
1. Read JavaScript preprocessing results from `UTType.propertyList`
2. If full page data cannot be parsed, try to recover URL from that same property-list payload
3. If URL still not found, try normal `UTType.url` attachments
4. Try plain text URL parsing
5. Fall back to image import

Important rule: if page-data parsing fails, still try URL import before failing.

## Common Failure Cases

### 1) Only `com.apple.property-list` attachment
Safari web-page shares often provide only a property-list attachment. Do not assume `public.url` appears as a separate attachment.

### 2) Empty JavaScript result dictionary
`NSExtensionJavaScriptPreprocessingResultsKey` can exist but be empty. This should not be treated as a final failure. URL fallback should still run.

### 3) Multiple extension input items
Data may be split across multiple `NSExtensionItem`s. Do not read only `inputItems.first`; flatten all attachments.

## What We Remove Before Sending HTML

`PreprocessingScript.js` intentionally strips noisy and large content before upload.

Removed tags:
- `script`, `style`, `nav`, `header`, `footer`, `aside`, `svg`, `iframe`, `noscript`
- `video`, `button`
- `form`, `input`, `select`, `option`, `textarea`, `label`
- `canvas`, `picture`, `source`, `template`, `dialog`

Removed attributes:
- `class`, `style`, `id`, `srcset`
- `poster`, `autoplay`, `controls`, `loading`, `decoding`
- all `data-*`, all `aria-*`, all `on*` event attributes

Other cleanup:
- remove HTML comments
- remove whitespace-only text nodes
- remove empty elements
- send only `<body>` HTML (`body.outerHTML`)

## JSON-LD Handling

For each JSON-LD block:
- try to parse JSON
- remove `review` and `aggregateRating` fields recursively
- serialize back to JSON string

If parsing fails for a block, send that block unchanged.

Server-side import treats `jsonLd` as untrusted input:
- each block is parsed directly as JSON (not wrapped into synthetic HTML)
- invalid blocks are ignored
- extraction proceeds with the first valid block containing a `Recipe`

## Debugging Checklist

Most useful logs:
- attachment type identifiers
- which path was used (full page data vs URL fallback)
- JavaScript result shape problems (for example empty dictionaries)

If sharing fails:
1. confirm JavaScript preprocessing ran (property-list path)
2. confirm URL fallback from property-list still works
3. check for server payload limit response (`413`, then client should fall back to URL-only import)

## Testing

`ShareImportExtractor` now depends on a small provider protocol (`ShareItemProviding`) instead of directly depending on `NSItemProvider`.
This keeps controller behavior unchanged but allows unit tests to use fake providers to verify fallback order and error handling without simulator-only share-extension plumbing.
