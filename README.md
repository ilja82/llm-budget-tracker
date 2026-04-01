# LiteBudget

A macOS Menu Bar app that tracks your [LiteLLM](https://github.com/BerriAI/litellm) proxy budget usage in real time.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Menu Bar display** — shows current spend as `$4.50`, `45%`, or a live progress bar (configurable)
- **Budget overview** — used, max budget, days until reset
- **Pacing indicator** — compares actual spend vs. expected spend at this point in the billing cycle; flags over- or under-pacing
- **Predicted total** — extrapolates your daily rate to the end of the budget window
- **Daily spend chart** — Swift Charts bar chart of spend per day in the current period
- **Background refresh** — polls the LiteLLM API on a configurable interval (default 60 min)
- **Secure storage** — API key is stored in the macOS Keychain, never displayed in plain text
- **Launch at login** — via `SMAppService`

---

## Requirements

| Tool | Version |
|---|---|
| macOS | 14 Sonoma or later |
| Xcode | 15 or later |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | 2.x |
| A running LiteLLM proxy | any recent version |

---

## Installation

### Option A — Homebrew (after a release is published)

```bash
brew tap ilja82/lite-budget
brew install --cask lite-budget
```

### Option B — Build from source

```bash
# 1. Clone
git clone https://github.com/ilja82/lite-budget.git
cd lite-budget

# 2. Install XcodeGen (if not already installed)
brew install xcodegen

# 3. Generate the Xcode project
xcodegen generate

# 4. Open in Xcode and run
open LiteBudget.xcodeproj
```

Press **⌘R** in Xcode to build and run. The app will appear in your menu bar immediately.

> **Note:** `LiteBudget.xcodeproj` is not committed — it is generated from `project.yml`.
> Run `xcodegen generate` after every `git clone` or `git pull` before opening Xcode.

---

## First-time setup

1. Click the menu bar icon (shows `$--.--` until configured).
2. Click **Settings** in the popover footer.
3. Enter your **LiteLLM Endpoint URL** (e.g. `https://your-litellm-proxy.com`).
4. Paste your **API key** into the secure field and click **Save** — it is written to the Keychain and never shown again.
5. Click **Refresh** or wait for the first automatic fetch.

---

## Configuration

All settings are in the **Settings** window (accessible from the popover or **⌘,**):

| Setting | Description | Default |
|---|---|---|
| Endpoint URL | Base URL of your LiteLLM proxy | — |
| API Key | `x-litellm-api-key` header value; stored in Keychain | — |
| Menu Bar Display | `$` dollar amount · `%` percentage · `Bar` progress bar | `$` |
| Refresh Interval | How often to poll the API (minutes) | 60 |
| Launch at Login | Register with `SMAppService` | Off |

---

## API endpoints used

| Endpoint | Purpose |
|---|---|
| `GET /v2/user/info` | Current spend, max budget, budget duration & reset date |
| `GET /spend/logs/v2` | Paginated spend logs for the daily chart |

The API key is sent as the `x-litellm-api-key` request header.

---

## Project structure

```
LiteBudget/
├── Models/
│   ├── BudgetInfo.swift          # Codable response from /v2/user/info
│   ├── SpendLog.swift            # Codable response from /spend/logs/v2
│   ├── PacingInfo.swift          # Computed pacing data (value type)
│   └── MenuBarDisplayMode.swift  # Enum for menu bar display preference
├── Services/
│   ├── APIService.swift          # URLSession actor — async/await networking
│   ├── KeychainService.swift     # Read/write API key to macOS Keychain
│   └── AutoStartService.swift    # SMAppService launch-at-login wrapper
├── ViewModels/
│   └── BudgetViewModel.swift     # @Observable — business logic & background timer
├── Views/
│   ├── MenuBarLabel.swift        # Menu bar icon (text or progress bar)
│   ├── PopoverView.swift         # Root popover window
│   ├── StatsView.swift           # Budget overview group box
│   ├── PacingView.swift          # Expected vs actual pacing group box
│   ├── UsageChartView.swift      # Swift Charts daily spend bar chart
│   └── SettingsView.swift        # Settings form window
├── LiteBudgetApp.swift           # @main — MenuBarExtra + Settings scenes
└── LiteBudget.entitlements
project.yml                       # XcodeGen project spec
Casks/lite-budget.rb              # Homebrew Cask formula
.github/workflows/build.yml       # CI/CD: build on PRs, DMG release on tags
```

---

## CI/CD

The GitHub Actions workflow (`.github/workflows/build.yml`) runs in two stages:

**On every pull request:**
- Installs XcodeGen, generates the project, builds unsigned — validates the code compiles.

**On `v*` tags (e.g. `git tag v1.2.0 && git push --tags`):**
1. Imports the Developer ID certificate from repository secrets.
2. Archives and exports the signed `.app`.
3. Notarizes with Apple.
4. Packages a `.dmg` with `create-dmg`.
5. Creates a GitHub Release and uploads the DMG.
6. Patches the SHA256 and version in `Casks/lite-budget.rb` and pushes the update.

### Required repository secrets

| Secret | Description |
|---|---|
| `MACOS_CERTIFICATE` | Base64-encoded `.p12` Developer ID certificate |
| `MACOS_CERTIFICATE_PWD` | Password for the `.p12` file |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_ID_PASSWORD` | App-specific password for notarization |
| `APPLE_TEAM_ID` | 10-character Apple Team ID |

---

## Releasing a new version

```bash
git tag v1.0.0
git push origin v1.0.0
```

The CI workflow handles everything else: sign → notarize → DMG → GitHub Release → Homebrew Cask update.