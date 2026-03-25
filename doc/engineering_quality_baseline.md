# Engineering Quality Baseline

This document defines the minimum quality baseline for `klas-cli` before wider rollout.

## CI Gates (Blocking)

All pull requests, direct pushes to `develop`, and release-only pushes to `main`/`master` must pass `.github/workflows/ci.yml`.

The workflow runs:

- `dart run tool/check_all.dart`

The gate script currently enforces:

1. dependency resolution (`dart pub get`)
2. static analysis (`dart analyze`)
3. unit/integration test suite (`dart test`)
4. root schema smoke check (`dart run bin/klas.dart --format json schema`)
5. schema smoke check (`dart run bin/klas.dart --format json schema tasks list`)
6. dry-run smoke check (`dart run bin/klas.dart --format json --dry-run tasks show 12 --course CSE101`)
7. installer contract tests (`dart test test/installers/install_contract_test.dart`)
8. publish dry-run (`dart pub publish --dry-run`)

## Test Policy

- Prefer deterministic tests (no network dependency by default).
- Add or update tests whenever command parsing, output schema, auth/session logic, or error mapping changes.
- Keep machine-readable output behavior (`--format json`, `--fields`, `--dry-run`) covered by tests.
- Live-account verification is optional and read-only; it is never a CI requirement.

## Release Criteria

Before release, all of the following must be true:

1. CI gate is green on the release commit.
2. `dart run tool/check_all.dart` passes locally (includes installer contract tests and publish dry-run).
3. `README.md`, `doc/json-contract.md`, and `CHANGELOG.md` match the shipped behavior.
4. `pubspec.yaml` version and release notes are updated together.
5. Operational confidence signals in `doc/operations_readiness.md` are reviewed; if you have dashboards/alerts, map them to those signals for this release.

For operator steps, follow `doc/release_checklist.md` and `doc/operations_readiness.md`.
