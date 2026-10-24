# Changelog

All notable changes to LLM Budget Tracker are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Highlights

- The effective budget limit is now resolved across key, team member, team and user levels; the lowest limit wins.
- Usage is shown even when no budget limit is configured.
- New "This week" and "Last week" ranges in the per-model spend breakdown.
- New "Quit App" button in the popover.

### For users

#### Added

- **Quit App** button next to "Settings" in the popover header.
- **"This week" and "Last week"** ranges in the per-model spend breakdown. Weeks always run Monday to Sunday,
  independent of your locale; "Last week" is the previous calendar week. All ranges are based on UTC, like the
  daily API data.
- **Budget limits from all levels:** besides the user (`/v2/user/info`) and team-member (`/team/{id}/members/me`)
  budgets, the app now also considers the key's own budget (`/key/info`) and the team budget (`/team/info`).
  If several limits are set, the lowest one is used, together with the spend, reset time and duration of that level.
- **Keep the saved API key:** if an API key is already stored, you can change only the proxy URL and leave the API key
  field empty. "Test Connection" then uses the saved key, and "Save" keeps it unchanged. A hint below the field
  explains this.

#### Changed

- **No budget limit is no longer an error.** Instead of "No budget found", the popover shows your spend so far and
  explains that remaining budget and pacing require a limit. The menu bar tooltip reads "Used: … / No budget limit
  configured."
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
- **`TeamInfo.swift`:** decoding of `GET /team/info` (team-level budget).
- **`ConnectionSettings.swift`:** testable form logic for the connection settings (form validation, which API key is
  used for testing, whether a key is saved).
- **`limits_found`** field in the Developer Mode request log, listing every limit that was found,
  e.g. `/key/info: $25.00, /v2/user/info: $100.00`.

#### Changed

- **`APIService.fetchResolvedBudgetInfo`** collects all sources with a limit as candidates and picks the lowest
  (`min(by:)` keeps the first of equal limits, so the more specific source wins ties). HTTP and decoding failures mark a
  source as unavailable via the new `bestEffort` helper; transport errors and cancellation still propagate. If no
  source has a limit, user-level usage is returned; if that also fails, its error is surfaced. A `/team/info` response
  without `team_info` fails decoding and is skipped.
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

[Unreleased]: https://github.com/ilja82/llm-budget-tracker/compare/v0.0.8...HEAD
