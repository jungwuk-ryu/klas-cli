# Implementation Plan

## Goal

Build a production-ready Dart CLI on top of `klasflow` that is safe for human students and reliable for AI agents, with text output by default and a stable JSON envelope for automation.

## Evidence Snapshot

- Local repo is greenfield: only `AGENTS.md` and `LICENSE` exist.
- Upstream `klasflow` is published on pub.dev and can be consumed as a hosted dependency.
- Verified upstream high-level APIs exist for login, session status, profile, personal info, courses, tasks, notices, timetable, monthly schedule, files, and downloads.
- Verified upstream does not expose a dedicated public `progress` CLI-ready API; only lower-level learning status/progress records are available.
- Upstream auto-renews only within a running process when credentials are cached in memory, so CLI disk-backed session handling is still needed.

## In Scope

- Initialize a standalone Dart CLI package with `bin/`, `lib/`, `test/`, and `doc/`.
- Add a thin adapter layer over `klasflow` public APIs.
- Implement auth/session management suitable for CLI usage.
- Implement text and JSON output contracts with structured errors and exit codes.
- Ship only command groups that are truthful on verified upstream capability.
- Add tests, README, contract docs, and an agent-facing local skill.

## Locked v1 Surface

- `auth login|status|logout`
- `me profile`
- `courses list|show`
- `tasks list|show`
- `notices list`
- `timetable week`
- `calendar month`

## Deferred Until Upstream Support Is Stronger

- `tasks due|overdue` — upstream task deadline semantics are not yet authoritative enough for a stable CLI contract.
- `notices show` — keep detail out of v1 until notice detail support is treated as a stable, explicit public CLI dependency.
- `files list|download` — upstream exposes file download by `attachId`, but not a verified user-level file index suitable for a truthful standalone CLI command.
- `progress by-course|show` — upstream exposes learning-status records, not a verified public progress aggregate.

## Implementation Steps

1. Create package scaffolding and dependency strategy for `klasflow`.
2. Build core CLI infrastructure: command runner, output formatter, error mapper, exit codes.
3. Build auth/session layer with secure local persistence and silent recovery where safe.
4. Add normalized domain models and services for profile, courses, tasks, notices, timetable, calendar, files, and any truthful progress view.
5. Add automated tests for parsing, output contracts, auth behavior, and core happy paths.
6. Update README, docs, and agent skill to match shipped behavior.
7. Add one-line installer scripts for Unix and Windows that bootstrap Dart when missing, activate the pub.dev package, and hand off to `klas auth login`.
8. Run analyze, tests, build, and manual CLI QA before final Oracle verification.

## Validation Targets

- `dart analyze`
- `dart test`
- `bash install.sh` in a clean environment without `dart` on `PATH`
- `dart run bin/klas.dart --help`
- Representative text/json command runs for shipped commands

## Risks

- `progress` semantics may be too unstable for a truthful public CLI contract.
- Persistent auth must avoid storing raw passwords, cookies, or student IDs insecurely.
- Upstream is still work-in-progress, so the CLI must keep its own stable normalization boundary.
