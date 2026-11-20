# Contributing to LLM Budget Tracker

Thank you for your interest in improving LLM Budget Tracker. This guide explains how to report problems, suggest ideas
and send changes.

By taking part in this project you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Report a Bug or Request a Feature

Open a [new issue](https://github.com/ilja82/llm-budget-tracker/issues/new/choose) and pick a form:

* **Bug report**: something does not work as expected.
* **Feature request**: an idea for something new or better.

Please search the existing issues first. Never paste a real API key or proxy URL into an issue.

Report security problems privately, as described in the [Security Policy](SECURITY.md), not in a public issue.

## Build from Source

A full Xcode installation is required (not just the Command Line Tools).

```bash
git clone https://github.com/ilja82/llm-budget-tracker.git
cd llm-budget-tracker
brew install xcodegen swiftlint
xcodegen generate
open LLMBudgetTracker.xcodeproj
```

The Xcode project is generated from `project.yml` and is not checked in. Run `xcodegen generate` again after you pull
changes or edit `project.yml`.

## Lint

The code must have 0 SwiftLint violations. Fix what can be fixed automatically, then check the rest:

```bash
swiftlint lint --fix
swiftlint lint
```

The pull request checks run `swiftlint lint --strict`, so warnings fail the check too.

## Tests

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme LLMBudgetTracker -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

Tests use mocked Keychain access and API responses. Do not add real credentials or calls to real services.

## Pull Requests

1. Fork the repository and create a branch from `main`.
2. Keep the change focused on one topic.
3. Run the lint and the tests, and make sure the app builds.
4. For a change users will notice, add an entry under `[Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md).
5. Open a pull request to `main` and fill in the template.

All pull request checks must pass before a change can be merged.
