---
paths: ["hauptgang-ios/**/*"]
---

# iOS App (hauptgang-ios)

The iOS app is a native SwiftUI application located in `hauptgang-ios/`.

## XcodeGen

This project uses **XcodeGen** to generate the Xcode project from `project.yml`. This eliminates manual `project.pbxproj` editing.

**IMPORTANT**: Never manually edit `Hauptgang.xcodeproj/project.pbxproj`. It is generated and will be overwritten.

## iOS Development Commands

```bash
# Run iOS tests (from project root)
bin/ios-test

# Regenerate Xcode project (from hauptgang-ios/)
cd hauptgang-ios && xcodegen generate
```

## Adding New Swift Files

1. Create the `.swift` file in the appropriate directory under `Hauptgang/`
2. Run `xcodegen generate` to update the project
3. Open Xcode or refresh if already open

The `project.yml` auto-discovers all `.swift` files, so no configuration changes are needed.
