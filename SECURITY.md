# Security Policy

## Supported Versions

Only the latest release of LLM Budget Tracker gets security fixes. Please update to the latest release before you
report a problem:

```bash
brew upgrade --cask ilja82/tap/llm-budget-tracker
```

| Version        | Supported |
|----------------|-----------|
| Latest release | Yes       |
| Older releases | No        |

## Reporting a Vulnerability

Please do not report security problems in public issues, pull requests or discussions.

Report them privately through GitHub instead:
[Report a vulnerability](https://github.com/ilja82/llm-budget-tracker/security/advisories/new). You can also open the
repository's **Security** tab and click **Report a vulnerability**. Only the maintainers can see the report.

Please include:

* the app version and macOS version,
* what an attacker could do and what is needed for it,
* the steps to reproduce the problem.

**Never include a real LiteLLM API key, a real proxy URL or other credentials** in a report, a log or a screenshot.
Replace them with placeholders such as `sk-REDACTED` and `https://proxy.example.com`. If a key was exposed, revoke it
in your LiteLLM proxy.

## What to Expect

This is a project maintained in spare time. Reports are handled on a best-effort basis, without a fixed response time.
You will get an answer in the report thread. When a fix is ready, it is shipped in a new release and the advisory is
published, with credit to you if you want it.
