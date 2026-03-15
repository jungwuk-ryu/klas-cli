# Engineering Quality Baseline

This document defines the minimum quality baseline for `klas-cli` before wider rollout.

## CI Gates (Blocking)

All pull requests and direct pushes to `main`/`master` must pass `.github/workflows/ci.yml`.

The workflow runs:

- `dart run tool/check_all.dart`

The gate script currently enforces:

1. dependency resolution (`dart pub get`)
2. static analysis (`dart analyze`)
3. unit/integration test suite (`dart test`)
4. command-contract smoke checks for:
   - `klas --format json schema tasks list`
   - `klas --format json --dry-run tasks show 12 --course CSE101`

## Test Policy

- Prefer deterministic tests (no network dependency by default).
- Add or update tests whenever command parsing, output schema, auth/session logic, or error mapping changes.
- Keep machine-readable output behavior (`--format json`, `--fields`, `--dry-run`) covered by tests.
- Live-account verification is optional and read-only; it is never a CI requirement.

## Release Criteria

Before release, all of the following must be true:

1. CI gate is green on the release commit.
2. `dart run tool/check_all.dart` passes locally.
3. Install contract tests remain green (`test/installers/install_contract_test.dart`).
4. `README.md`, `doc/json-contract.md`, and `CHANGELOG.md` match the shipped behavior.
5. `pubspec.yaml` version and release notes are updated together.

For operator steps, follow `doc/release_checklist.md`.
