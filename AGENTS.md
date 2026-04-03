# LLM Budget Tracker

## Build

After making code changes, verify the build compiles without errors using:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LLMBudgetTracker -destination 'platform=macOS' build
```

The `DEVELOPER_DIR` prefix is required because the default developer directory points to Command Line Tools, not the full Xcode installation. Without it, `xcodebuild` will fail with "requires Xcode, but active developer directory is a command line tools instance". Do not use `sudo xcode-select` to change it — just prefix the command as shown.

To reduce noise, pipe through grep to show only errors and the build result:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LLMBudgetTracker -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD"
```