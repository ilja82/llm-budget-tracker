# Instructions

## Build

After making code changes, run `xcodegen generate` to update the Xcode project. Then verify the build compiles without errors using:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LLMBudgetTracker -destination 'platform=macOS' build
```

The `DEVELOPER_DIR` prefix is required because the default developer directory points to Command Line Tools, not the full Xcode installation.

To reduce noise, pipe through grep to show only errors and the build result:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LLMBudgetTracker -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD"
```