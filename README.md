# LLM Budget Tracker

The LLM Budget Tracker is a macOS application that sits in your status bar and monitors your LiteLLM budget usage. It retrieves your budget from your
LiteLLM proxy and displays daily activity charts.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)

## What it does

- Shows current budget usage directly in the macOS status bar.
- Colors the menu bar progress indicator based on pacing status.
- Opens a popover with remaining budget, reset timing, projected spend, and pacing details.
- Optionally loads daily activity data for spend, token usage, and request success/failure charts.

## Install the app

Use homebrew to install the app:

```bash
brew tap ilja82/tap
brew install --cask llm-budget-tracker
```

## Run the app

Open the installed app `llmBudgetTracker.app` using Spotlight (`⌘` + `SPACE`). The app will then appear in the menu bar.

## Configure the app

Click the menu bar item, then open Settings.

* Enter your LiteLLM proxy URL and API key, test the connection.
* Activate `Launch at Login` if you want the app to start automatically on system startup.
* Save the settings.

## Build from source

```bash
# 1. Clone
git clone https://github.com/ilja82/llm-budget-tracker.git
cd llm-budget-tracker

# 2. Install XcodeGen (if not already installed)
brew install xcodegen

# 3. Generate the Xcode project
xcodegen generate

# 4. Open in Xcode and run
open LLMBudgetTracker.xcodeproj
```

In Xcode run `⌘` + `R` to build and run the app.

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.