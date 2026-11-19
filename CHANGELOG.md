# Changelog

All notable changes to LLM Budget Tracker are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Highlights

- The effective budget limit is now resolved across key, team member, team and user levels; the level with the least
  remaining budget wins.
- Usage is shown even when no budget limit is configured.
- New "This week" and "Last week" ranges in the per-model spend breakdown.
- New "Quit App" button in the popover.
- The popover tells you when a newer version is available and how to update it with Homebrew.
- New dashboard window with the daily cost per model and more statistics and charts.

### For users

#### Added

- **Quit App** button next to "Settings" in the popover header.
- **Dashboard window:** "Details" below the per-model spend chart opens a resizable window with two pages, using the
  same range as the per-model chart. "Daily costs" lists each day with the total reported by LiteLLM and its parts per
  model ($ and % of the day). Spend LiteLLM does not attribute to a model shows as "Other / unattributed" (or
  "Unattributed" for days without a breakdown); if the parts add up to more than the total, the day is marked
  "parts ≠ total". "Statistics" shows tiles for total spend, average per active day, most expensive day, requests,
  failure rate, tokens, cost per 1K tokens and top model, plus charts for daily tokens, daily requests, spend share
  by model and spend by weekday. Both pages use the daily activity data that is already loaded; no new requests.
- **Update notice:** when a newer release is available, a banner at the top of the popover shows the new and the
  current version and the steps to update (`brew update`, `brew upgrade --cask llm-budget-tracker`, quit the app,
  start it again). "Copy Commands" copies both commands; "Dismiss" hides the notice until a newer version comes out.
  The app asks GitHub at most every 12 hours and only announces a release once it is at least 12 hours old. Nothing is
  installed automatically; offline, nothing is shown. Turn it off with **Check for Updates** in Settings.
- **"This week" and "Last week"** ranges in the per-model spend breakdown. Weeks always run Monday to Sunday,
  independent of your locale; "Last week" is the previous calendar week. All ranges are based on UTC, like the
  daily API data.
- **Budget limits from all levels:** besides the user (`/v2/user/info`) and team-member (`/team/{id}/members/me`)
  budgets, the app now also considers the key's own budget and its `budget_limits` windows (`/key/info`), the team
  budget and the team's default member budget (`/team/info`). If several limits are set, the one with the least
  remaining budget is used, together with the spend, reset time and duration of that level. For keys that belong to a
  team, the user limit is skipped, like LiteLLM does by default.
- **Keep the saved API key:** if an API key is already stored, you can change only the proxy URL and leave the API key
  field empty. "Test Connection" then uses the saved key, and "Save" keeps it unchanged. A hint below the field
  explains this.
- **LiteLLM temporary budget increases:** while a key or team-member budget has an active "Temporary Budget Increase"
  (expiry in the future), the app uses the raised cap (`max_budget` + increase), like LiteLLM does, for the remaining
  budget, percentage, pacing and the choice of the most limited level. A member without its own budget gets the
  increase on top of the team's default member budget. The popover shows "Includes temporary +$X until …" and the
  menu bar tooltip lists the increase. After the expiry the base cap is back with the next refresh. Key
  `budget_limits` windows are not raised.

#### Changed

- **Slower polling after repeated errors:** after 9 failed refreshes in a row the app polls once per hour instead of
  every 30 seconds to 5 minutes. The first successful refresh restores the normal interval.
- **macOS 27 or later is now required.** The app is built for macOS 27; Macs on macOS 26 can keep using v0.0.8.
- **No budget limit is no longer an error.** Instead of "No budget found", the popover shows your spend so far and
  explains that remaining budget and pacing require a limit. The menu bar tooltip reads "Used: … / No budget limit
  configured."
- **Percent display without a limit:** the menu bar shows the spend in dollars instead of "N/A".
- **Daily activity charts no longer require a budget reset date** and are also available without a budget limit.
- **"All Models" filter:** the model menu above the daily activity chart now uses the same bordered style as the
  "Spend / Tokens / Requests" control and shows a single chevron instead of two.
- **VoiceOver:** without a budget limit, the menu bar item is announced as "Used …, no budget limit" instead of
  "No budget available".

#### Fixed

- A team membership without its own budget could produce a zero-spend row that hid the real budget; such rows are now
  ignored.
- The IPv6 loopback address `http://[::1]` is now accepted as a local proxy URL.
- Proxy URLs without a host are now rejected.

### For developers

#### Added

- **Unit test target `LLMBudgetTrackerTests`** with suites for budget usage, connection settings, daily activity,
  endpoint security, model ranges and response sanitizing. Tests use mocked Keychain access and API responses; no real
  credentials or network access are needed. The scheme collects code coverage.
- **`UpdatePolicy`, `UpdateChecker`, `UpdateViewModel`, `UpdateNoticeView`:** update check against
  `GET /repos/ilja82/llm-budget-tracker/releases/latest` with its own ephemeral `URLSession`, version compare and
  12-hour rules in the pure `UpdatePolicy.availableUpdate`, new `update.*` keys in `StorageKeys`. Covered by
  `UpdatePolicyTests` and `UpdateViewModelTests`.
- **`DailyCostBreakdown`, `DashboardStats`:** pure functions behind the dashboard (day rows with per-model parts,
  summary values and chart series), sharing one range filter. Covered by `DailyCostBreakdownTests` and
  `DashboardStatsTests`.
- **`TeamInfo.swift`:** decoding of `GET /team/info` (team-level budget).
- **`ConnectionSettings.swift`:** testable form logic for the connection settings (form validation, which API key is
  used for testing, whether a key is saved).
- **`limits_found`** field in the Developer Mode request log, listing every limit that was found,
  e.g. `/key/info: $7.00 of $25.00, /v2/user/info: $12.50 of $100.00`.
- **`TemporaryBudgetIncrease`:** reads `metadata.temp_budget_increase` / `metadata.temp_budget_expiry` from
  `/key/info` and `litellm_budget_table.temp_budget_increase` / `temp_budget_expiry` from `/team/{id}/members/me`.
  `activeAmount(at:)` decides whether an increase is active. `APIService.init` takes an injectable `now` clock.
  New request log fields `temp_budget_increase` and `temp_budget_expiry`. Covered by `TemporaryBudgetIncreaseTests`
  and new `BudgetUsageTests` scenarios.

#### Changed

- **`APIService.fetchResolvedBudgetInfo`** collects all sources with a limit as candidates and picks the one with
  the least remaining budget (`min(by:)` keeps the first of equal values, so the more specific source wins ties).
  HTTP and decoding failures mark a source as unavailable via the new `bestEffort` helper; transport errors and
  cancellation still propagate. If no source has a limit, user-level usage is returned without a limit; if that also
  fails, its error is surfaced. A `/team/info` response without `team_info` fails decoding and is skipped.
- **`APIService.init`** accepts a `URLSessionConfiguration` (default `.ephemeral`) so tests can inject a mock protocol.
- **`KeyInfoDetails`** now also decodes `user_id`, `spend`, `max_budget`, `budget_duration` and `budget_reset_at`
  (leniently, so an unexpected shape never hides the team attachment). `KeyInfoFetch` exposes `details` instead of
  `teamId`; `teamId` remains as a computed property.
- **`BudgetFetchResult`** has a new `limitSources` field.
- **`BudgetInfo`** gained `hasBudgetLimit`, `canLoadDailyActivity` and `withUserId(_:)`.
- **`BudgetViewModel`:** `.noBudget` is now set after a regular load (budget info and daily activity are kept)
  instead of clearing the data; pacing stays `nil` without a limit. `StatsView` renders `.noBudget` like `.loaded`.
  Daily activity is gated on `canLoadDailyActivity` (a known user ID) instead of `budgetResetAt`.
- **Date ranges moved into `ModelRange.dateRange(relativeTo:)`** in `ChartSelection.swift`. It returns a half-open UTC
  `Range<String>` (`yyyy-MM-dd`) instead of a start-only cutoff, which is needed for "Last week".
  `modelGroupSpendTotals(range:)` in `BudgetViewModelSupport.swift` now only uses this range.
- **`EndpointSecurity`:** the loopback allow list contains `[::1]` (the host as reported by `URLComponents`), and
  empty hosts are rejected.
- **SwiftLint** now also lints `LLMBudgetTrackerTests`.
- **Toolchain:** the project targets Xcode 27 (`xcodeVersion: "27.0"` in `project.yml`) and macOS 27.0 as the
  deployment target (was Xcode 26.5 and macOS 26.0). CI must build on a macOS 27 runner with Xcode 27.

[Unreleased]: https://github.com/ilja82/llm-budget-tracker/compare/v0.0.8...HEAD
