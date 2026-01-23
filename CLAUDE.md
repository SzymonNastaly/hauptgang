# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hauptgang is a Rails 8.1 application using Ruby 3.4.7. It follows Rails conventions and uses modern Rails 8+ features including:

- **Hotwire** (Turbo and Stimulus) for SPA-like interactions
- **SQLite multi-database setup** - Rails 8+ approach using separate SQLite databases for:
  - `primary`: Main application data
  - `cache`: Solid Cache storage (migrations in `db/cache_migrate`)
  - `queue`: Solid Queue storage (migrations in `db/queue_migrate`)
  - `cable`: Solid Cable storage (migrations in `db/cable_migrate`)
- **Solid suite** (Solid Cache, Solid Queue, Solid Cable) for caching, background jobs, and WebSockets
- **Tailwind CSS v4** via `tailwindcss-rails` gem
- **Importmap** for JavaScript (no Node.js/npm required)

## Essential Commands

```bash
# Setup & Development
bin/setup                    # Install dependencies, prepare database, start server
bin/dev                      # Start development server

# Quality Checks
bin/ci                       # Run full CI suite (style, security, tests)
bin/rubocop -a               # Auto-fix Ruby style issues

# Standard Rails commands for database, testing, etc. work as expected
```

## Code Style

This project uses **rubocop-rails-omakase** for Ruby styling, which provides standardized Rails conventions from Basecamp/37signals. Follow these standards when writing code.

## Git Commit Messages

When creating git commits:

- **DO NOT** include "Co-Authored-By: Claude" or any similar AI attribution in commit messages
- Keep commit messages clear and focused on what changed and why
- Follow conventional commit message format when appropriate

## CI Requirements

Run `bin/ci` before committing. All checks (style, security audits, tests) must pass before merging.

## iOS App (hauptgang-ios)

The iOS app is a native SwiftUI application located in `hauptgang-ios/`.

### XcodeGen

This project uses **XcodeGen** to generate the Xcode project from `project.yml`. This eliminates manual `project.pbxproj` editing.

**IMPORTANT**: Never manually edit `Hauptgang.xcodeproj/project.pbxproj`. It is generated and will be overwritten.

### iOS Development Commands

```bash
cd hauptgang-ios

# Regenerate Xcode project (run after adding/removing files)
xcodegen generate

# Build from command line
xcodebuild -project Hauptgang.xcodeproj -scheme Hauptgang -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Adding New Swift Files

1. Create the `.swift` file in the appropriate directory under `Hauptgang/`
2. Run `xcodegen generate` to update the project
3. Open Xcode or refresh if already open

The `project.yml` auto-discovers all `.swift` files, so no configuration changes are needed.
