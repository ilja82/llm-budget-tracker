# Instructions

## Build

After making code changes:

1. Auto-fix any SwiftLint violations:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint --fix
```

2. Check for remaining violations that require manual fixes:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint 2>&1 | grep -E "warning:|error:"
```

Resolve all remaining violations before proceeding. Only continue once `swiftlint lint` reports 0 violations.

3. Regenerate the Xcode project and build. The project file is git-ignored, so always run `xcodegen generate` first:

```
xcodegen generate && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LLMBudgetTracker -destination 'platform=macOS' build
```

The `DEVELOPER_DIR` prefix is required because the default developer directory points to Command Line Tools, not the full Xcode installation.

To reduce noise, pipe through grep to show only errors and the build result:

```
xcodegen generate && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LLMBudgetTracker -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD"
```