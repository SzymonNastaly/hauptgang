# Hauptgang

A recipe manager with a Rails API backend, a SwiftUI iOS app, and RevenueCat subscriptions.

Import recipes from URLs, text, or photos. The server extracts structured data using JSON-LD or an LLM, then serves it to the iOS app for offline-first access. A shopping list lets users collect ingredients across recipes.

See [architecture.md](architecture.md) for a deeper look at how the pieces fit together, and [written_proposal.md](written_proposal.md) for the original project proposal.

## Setup

Requires Ruby 3.4.7 and SQLite.

```bash
bin/setup    # install deps, prepare DB, start server
```

Or, to skip starting the server:

```bash
bin/setup --skip-server
bin/dev                    # start server separately
```

The iOS app lives in `hauptgang-ios/` and uses XcodeGen — run `xcodegen` to regenerate the Xcode project.

## Development

```bash
bin/dev          # start Rails dev server
bin/ci           # run full CI suite (style, security, tests)
bin/rubocop -a   # auto-fix Ruby style
bin/rails test   # run Rails tests
bin/ios-test     # run iOS tests
```

`bin/ci` runs rubocop, reek, brakeman, bundler-audit, importmap audit, iOS linting, Rails tests, system tests, and seed verification.

## Deployment

Deployed with Kamal to a Hetzner VPS. SQLite databases and uploads persist in a Docker volume.

```bash
kamal deploy     # full deploy
kamal app logs   # tail logs
```
