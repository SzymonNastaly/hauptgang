# CLAUDE.md - iOS App

This file provides guidance to Claude Code when working with the Hauptgang iOS app.

## Project Overview

Native SwiftUI app for iOS 17+ that communicates with the Rails backend API. Uses MVVM architecture with async/await networking.

## Essential Commands

```bash
# From project root (hauptgang/):
bin/ios-test         # Run all iOS tests (auto-finds simulator)

# From hauptgang-ios directory:
xcodegen generate    # Regenerate Xcode project after adding/removing files
```

### Manual xcodebuild (if needed)

```bash
# List available simulators to find a UUID
xcrun simctl list devices available | grep iPhone

# Build/test using a specific simulator ID
xcodebuild -project Hauptgang.xcodeproj -scheme Hauptgang \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' build
xcodebuild -project Hauptgang.xcodeproj -scheme Hauptgang \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' test
```

## XcodeGen Rules

**IMPORTANT**: This project uses XcodeGen to generate the Xcode project from `project.yml`.

- **NEVER** manually edit `Hauptgang.xcodeproj/project.pbxproj`
- After adding/removing `.swift` files, run `xcodegen generate`
- The `project.yml` auto-discovers all `.swift` files in `Hauptgang/`
- Only edit `project.yml` to change build settings, add dependencies, or modify schemes

## Architecture

```
Hauptgang/
├── App/           # @main entry point (HauptgangApp.swift)
├── Models/        # Data models (Codable structs matching Rails JSON)
├── ViewModels/    # @Observable view models, business logic
├── Views/         # SwiftUI views (declarative UI)
├── Services/      # APIClient, KeychainService, AuthService
├── Utilities/     # Constants, extensions, theme helpers
└── Resources/     # Assets.xcassets, Info.plist
```

### Key Patterns

- **APIClient** (`Services/APIClient.swift`): Singleton actor for all HTTP requests. Uses `async/await`, handles snake_case ↔ camelCase conversion automatically.
- **AuthManager** (`ViewModels/AuthManager.swift`): Global auth state using `@Observable`. Inject via `.environment()`.
- **KeychainService**: Secure token storage. Never store auth tokens in UserDefaults.

## Rails API Integration

The iOS app consumes the Rails JSON API at `/api/v1/`. When working on iOS features:

1. Check the Rails API endpoint exists: look in `app/controllers/api/v1/`
2. Match iOS model properties to Rails JSON keys (snake_case in Rails → camelCase in Swift)
3. API base URL is configured in `Utilities/Constants.swift` (different for DEBUG vs Release)

### Example: Adding a New API Feature

1. Verify Rails endpoint and JSON structure
2. Create/update Model in `Models/` with `Codable` conformance
3. Add service method in appropriate `Services/` file
4. Update ViewModel to call service
5. Update View to display data

## Code Style

- Use Swift's modern concurrency (`async/await`, actors) - no completion handlers
- Prefer `@Observable` (iOS 17+) over `@ObservableObject`
- Use `#Preview` macro for SwiftUI previews
- Keep views simple; move logic to ViewModels
- Use `Constants` enum for magic strings/URLs

## Testing

- Unit tests go in `HauptgangTests/`
- Test ViewModels by mocking Services
- Run tests: `xcodebuild test` or Cmd+U in Xcode
