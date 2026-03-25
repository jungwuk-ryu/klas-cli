# Operations Readiness

This document is the operator companion to:

- `doc/engineering_quality_baseline.md`
- `doc/release_checklist.md`

It focuses on release confidence signals and lightweight incident response for `klas-cli`, without assuming any existing production monitoring stack.

## Scope

This guide covers:

- Release confidence signals that can be captured from CLI commands and CI logs
- Install smoke signals for the public installer entrypoints
- Command health signals, including partial results for fan-out commands
- What to do when a release looks unhealthy

This guide does not define infrastructure, dashboards, or paging. If you do have those, map the signals in this doc into your tooling.

## Branching model for operations

- `develop` is the integration branch for day-to-day work.
- Feature, fix, and chore changes should arrive through short-lived branches based on `develop`.
- `main` is the canonical release branch when a single release branch name is needed in hosting or automation.
- If a release hotfix lands on `main`/`master`, merge it back into `develop` before the next routine development cycle continues.

## Primary release confidence gate

The single best automated signal is the CI aligned gate script:

```bash
dart run tool/check_all.dart
```

Per `doc/engineering_quality_baseline.md`, this gate includes:

- `dart pub get`
- `dart analyze`
- `dart test`
- Schema smoke checks (`klas ... schema ...`)
- Dry-run smoke check (`--dry-run`)
- Installer contract tests (`test/installers/install_contract_test.dart`)
- Publish dry-run (`dart pub publish --dry-run`)

Operator rule: if you have to choose only one automated pass/fail signal to record for a release candidate, record the result and logs from `dart run tool/check_all.dart`.

## What to monitor for release confidence

Treat the items below as signals. You can record them in a release issue, a runbook log, or a real dashboard.

### Command health signals

Minimal command health checks (no network required):

```bash
dart run bin/klas.dart --help
dart run bin/klas.dart --format json schema
dart run bin/klas.dart --format json schema tasks list
dart run bin/klas.dart --format json --dry-run tasks show 12 --course CSE101
```

What to look for:

- `--format json` mode prints only JSON to stdout, and any guidance goes to stderr.
- `schema` output is present and stable enough to drive automation.
- `--dry-run` returns a success envelope and does not attempt network calls.

If these break, treat it as a high severity regression because they are used for automated integration and quick smoke checks.

### Installer smoke signals

Install entrypoints are part of the release contract because they are the first thing most users run:

- `install.sh`
- `install.ps1`

At minimum, after a release is tagged and published, verify on a clean environment:

- The installer runs to completion.
- `klas --help` works.
- `klas auth status` works (it may report unauthenticated, but it should not crash).

If you have any kind of install smoke monitoring, keep it simple: one scheduled run per platform that only checks installation and `--help`, then alerts on failure.

### Publish dry-run and package metadata

The publish dry-run is already part of the main gate:

```bash
dart pub publish --dry-run
```

Operator rule: if the dry-run starts failing for a release candidate, stop and fix the package metadata or content drift before publishing.

### Release branch promotion

Before promoting a release to `main`/`master`, confirm:

- the candidate was validated on `develop`
- version and `CHANGELOG.md` updates are included in the release candidate
- installer entrypoints still reflect the intended stable release channel

After a release or release hotfix, confirm the same commit content is merged back into `develop` or that an equivalent follow-up commit has restored branch parity.

### Auth and session regression signals

Auth is a common source of user-facing incidents. Watch for regressions in:

- `AUTH_REQUIRED` vs interactive prompts (JSON output must stay clean on stdout)
- `AUTH_INVALID_CREDENTIALS` mapping and hint text
- `AUTH_EXPIRED` handling and automatic recovery behavior

Practical checks:

- In JSON mode, confirm failures produce a structured `error` with a stable `code`.
- Confirm no sensitive values are printed in errors or logs.

If you can do a read-only live check, use a dedicated test account and stick to commands that do not mutate state.

### Fan-out commands and partial result behavior

`tasks list` and `notices list` may query multiple courses. The contract described in `doc/json-contract.md` and `README.md` is:

- If at least one course succeeds, return `ok=true`, include usable `data`, and include per-course failures in `warnings`.
- If all selected courses fail, return a top-level structured error (`ok=false`).

Operational implications:

- Track the rate of `warnings` for these commands. A sudden increase usually means upstream slowness, auth expiration loops, or a parsing regression.
- Treat all-fail responses as incidents if they spike, even if the CLI remains responsive.

Release confidence check:

- Validate the all-fail behavior matches the contract. If an all-fail fan-out returns `ok=true` with empty `data` plus warnings, treat it as a contract regression.

## Incident response quick guide

This section is meant to be runnable by someone who did not ship the change.

### First questions

1. What version is affected?
2. Is it install failure, command parsing failure, JSON contract failure, auth/session failure, or upstream/network failure?
3. Is the problem reproducible with `--format json` and the smoke commands listed in this doc?

### Data to collect

Capture the smallest reproducible record:

- OS and shell (macOS, Linux distro, Windows PowerShell)
- `klas --version` if available, or the package version installed
- Exact command line
- Full JSON stdout (for `--format json`), and stderr separately

Do not capture or share credentials, cookies, student IDs, or raw session material.

### Triage by symptom

Install smoke fails:

- Re-run installer contract tests: `dart test test/installers/install_contract_test.dart`.
- Verify the install script URLs and release channel references.

Schema or dry-run smoke fails:

- Run `dart run tool/check_all.dart` and use its first failing step as the starting point.
- Treat schema regressions as high severity because they break agent integrations.

Auth failures spike:

- Confirm errors map to stable codes (`AUTH_REQUIRED`, `AUTH_EXPIRED`, `AUTH_INVALID_CREDENTIALS`).
- Check for stdout contamination in JSON mode.

Fan-out warnings spike:

- Confirm warnings are reported in the `warnings` array and that `ok` remains true when at least one course succeeds.
- If all courses fail, confirm the response is `ok=false` and that the error code is appropriate (`NETWORK_ERROR`, `AUTH_EXPIRED`, or `INTERNAL_ERROR`).

### Stabilization options

Prefer actions that restore the published contract quickly:

- If install scripts are broken, fix them first and verify with installer contract tests.
- If the JSON envelope or error codes drifted, restore the documented contract before adding new fields.
- If the issue is a real upstream outage, focus on clear retryable errors and keep partial results working.

In most cases, the fastest safe path is a patch release that restores the expected behavior and is verified by `dart run tool/check_all.dart`.

## Notes for operators

- The most reliable signals in this repo are command-based and CI-log-based. Start there.
- Keep a short release log with links to the gate output, install smoke results, and any known warnings spikes.
- When in doubt, treat contract regressions as incidents. This is an agent-first CLI, so predictability is part of uptime.
