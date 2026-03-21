---
name: hauptgang-ios-agent-build
description: >-
  Build and verify the Hauptgang iOS app from agents (XcodeBuildMCP CLI, xcodebuild)
  without slow failures. Covers XcodeGen, simulator destination pitfalls, sandbox
  permissions, and when to use bin/ios-test. Use when an agent runs iOS builds,
  xcodebuildmcp, or validates compiler warnings in hauptgang-ios.
---

# Hauptgang iOS — agent-friendly builds

Use this for **automated / Cursor** builds of the native app under `hauptgang-ios/`. It complements human workflows in `hauptgang-ios/CLAUDE.md` and generic `asc-xcode-build` (archive/export).

## Project facts (do not guess)

| Item | Value |
|------|--------|
| App directory | `hauptgang-ios/` (repo root is `hauptgang/`) |
| Project generator | **XcodeGen** — source of truth is `hauptgang-ios/project.yml` |
| Generated project | `hauptgang-ios/Hauptgang.xcodeproj` (do not hand-edit `project.pbxproj`) |
| Main scheme | `Hauptgang` |
| SPM packages | RevenueCat, GRDB (first resolve can be slow) |

After any change to `project.yml`: run from `hauptgang-ios/`:

```bash
xcodegen generate
```

## 1. Permissions: why builds fail or crawl in agents

`xcodebuild` and **XcodeBuildMCP** need the real macOS developer environment:

- **CoreSimulator** (simulator service, device list)
- **SwiftPM** caches under `~/Library/Caches/org.swift.swiftpm/`
- Often **DerivedData** under `~/Library/Developer/Xcode/DerivedData/`

In Cursor’s sandbox, simulator and package resolution often fail (`Operation not permitted`, `Connection refused` to CoreSimulator, SwiftPM manifest `.dia` errors).

**Rule:** When invoking `xcodebuild`, `xcodebuildmcp`, or `xcrun simctl` from an agent, request **full permissions** (e.g. `all` / non-sandboxed) unless you know the command is workspace-only.

## 2. Simulator destination: avoid `OS:latest` + name mismatches

`xcodebuildmcp simulator build-sim --simulator-name "iPhone 16 Pro"` resolves something like `platform=iOS Simulator, OS:latest, name=iPhone 16 Pro`. On machines with **multiple Xcode runtimes** (e.g. iOS 18.x and 26.x), **“latest” may be a runtime where that device name does not exist**, so the build fails immediately after a long dependency phase.

**Preferred:** pick a concrete simulator **UDID** once, then reuse it.

```bash
cd hauptgang-ios
xcodebuild -project Hauptgang.xcodeproj -scheme Hauptgang -showdestinations 2>/dev/null \
  | grep "platform:iOS Simulator" | head -20
```

Or:

```bash
xcrun simctl list devices available | grep -E "iPhone|iPad"
```

Then build with that id:

```bash
xcodebuildmcp simulator build-sim \
  --scheme Hauptgang \
  --project-path "$(pwd)/Hauptgang.xcodeproj" \
  --simulator-id YOUR-UDID-HERE
```

Plain `xcodebuild` (good for grepping warnings):

```bash
xcodebuild -project Hauptgang.xcodeproj -scheme Hauptgang \
  -destination 'platform=iOS Simulator,id=YOUR-UDID-HERE' \
  build 2>&1 | tee /tmp/hg-build.log
```

## 3. Speed: incremental vs clean

- **Default:** `build` without `clean` — reuse DerivedData; much faster for “did we fix warnings?”
- **Clean** only when debugging stale build state or after large project file changes.

## 4. When to use repo scripts vs raw xcodebuild

| Goal | Command |
|------|--------|
| Full test suite (human or CI-style) | From repo root: `bin/ios-test` |
| Quick compile check + warnings | `xcodebuild … build` with fixed simulator `id` (see above) |
| Install/run on sim via MCP | XcodeBuildMCP `build-sim` + follow-up “get app path / launch” hints from tool output |

## 5. XcodeBuildMCP CLI notes

- Discover tools: `xcodebuildmcp --help`, `xcodebuildmcp simulator build-sim --help`
- **`--os-version` is not a flag** on `build-sim`; use `--simulator-id` instead
- If `build-sim` fails on destination resolution, switch to **UDID** immediately rather than retrying different names

## 6. Checklist before reporting “build succeeded / no warnings”

1. `xcodegen generate` if `project.yml` changed
2. Agent command ran with **non-sandboxed** permissions
3. Destination is a **valid** `platform=iOS Simulator,id=…` for this machine
4. For warning sweeps, consider: `… build 2>&1 | grep -E "warning:|error:"` (filter noise from DVT/AppIntents if needed)
