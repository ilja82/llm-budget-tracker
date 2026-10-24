# LLM Budget Tracker

The LLM Budget Tracker is a macOS application that sits in your status bar and monitors your LiteLLM budget usage. It retrieves your budget from your
LiteLLM proxy and displays daily activity charts.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)

## What it does

- Shows current budget usage directly in the macOS status bar.
- Colors the menu bar progress indicator based on pacing status.
- Opens a popover with remaining budget, reset timing, projected spend, and pacing details.
- Optionally loads daily activity data for spend, token usage, and request success/failure charts, filterable by model.
- Breaks down spend per model for "This month", "Last 28 days", "This week", and "Last week" (weeks run Monday to Sunday).
  Like the daily API data, these ranges are based on UTC.
- Shows spend even without a configured budget limit. Remaining budget and projections require a limit;
  daily charts require neither a limit nor a budget reset time.
- Resolves the budget limit across all available levels: key (`/key/info`), team member (`/team/{id}/members/me`),
  team (`/team/info`), and user (`/v2/user/info`). If several limits are set, the lowest one applies; spend, reset time,
  and duration come from the same level. On equal limits, the level listed first wins. Levels without a limit or without
  access are skipped. In the Developer Mode request log, `limits_found` shows which limits were found.
- If no limit is found, the user data (spend) is shown.

## Install the app

Use homebrew to install the app:

```bash
brew install --cask ilja82/tap/llm-budget-tracker
```

## Run the app

Open the installed app `LLMBudgetTracker.app` using Spotlight (`⌘` + `SPACE`). The app will then appear in the menu bar.
To quit the app, click `Quit App` in the popover.

## Configure the app

Click the menu bar item, then open Settings.

* Enter your LiteLLM proxy URL and API key, test the connection.
* Activate `Launch at Login` if you want the app to start automatically on system startup.
* Save the settings.
* If an API key is already saved, you can change only the URL and leave the API key field empty.
  `Test Connection` then uses the saved key, and `Save` keeps it unchanged.
  Only enter a new key if you want to replace the existing one.
* Use HTTPS for remote proxies. HTTP is only allowed for local loopback addresses.

## Build from source

A full Xcode installation is required (not just the Command Line Tools).

```bash
# 1. Clone
git clone https://github.com/ilja82/llm-budget-tracker.git
cd llm-budget-tracker

# 2. Install XcodeGen and additional tools (if not already installed)
brew install xcodegen swiftlint

# 3. Generate the Xcode project
xcodegen generate

# 4. Open in Xcode and run
open LLMBudgetTracker.xcodeproj
```

In Xcode run `⌘` + `R` to build and run the app.

## Tests

The unit tests cover connection settings, endpoint security, response sanitizing, budget data, daily activity, and
analysis ranges, using mocked Keychain access and API responses, without real credentials or external services.

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme LLMBudgetTracker -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
