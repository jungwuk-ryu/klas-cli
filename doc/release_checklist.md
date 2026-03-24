# Release Checklist

## 1) Required quality gates

- Run `dart run tool/check_all.dart`.
  - This is the primary local quality gate. It includes dependency resolution, static analysis, the full test suite, root schema smoke, schema smoke (`schema tasks list`), dry-run smoke, installer contract tests, and `dart pub publish --dry-run`.
- Confirm CI passes on the release commit (`.github/workflows/ci.yml` runs the same gate script).
- If you operate install-smoke monitoring/alerts, confirm they are configured for this release. If an operations guide exists, follow `doc/operations_readiness.md`.

## 2) Contract and docs consistency

- Verify `README.md` command examples match actual behavior.
- Verify the frozen `1.0.0` reduced surface matches runtime discovery (`dart run bin/klas.dart --help` and `klas schema ...`), and that deferred commands remain unshipped: `tasks due`, `tasks overdue`, `notices show`, `progress`, `files`.
- Verify `doc/json-contract.md` matches the current envelope and error shape.
- Add release notes to `CHANGELOG.md`.

## 3) Packaging and installation

- Ensure `pubspec.yaml` version is updated for release.
- Ensure installer contract tests and publish dry-run are included in your release verification path.
  - Covered by `dart run tool/check_all.dart`.
  - For debugging, run `dart test test/installers/install_contract_test.dart` and `dart pub publish --dry-run` directly.
- Verify install scripts still point to the intended package/release channel:
  - `install.sh`
  - `install.ps1`

## 4) Optional local debugging checks

- `dart run tool/check_all.dart` is the release proof. Use the commands below only when debugging failures or doing quick local spot checks.

- `dart run bin/klas.dart --help`
- `dart run bin/klas.dart --format json schema tasks list`
- `dart run bin/klas.dart --format json --dry-run tasks show 12 --course CSE101`

## 5) Operational readiness

- Review the operations readiness guide, if present: `doc/operations_readiness.md`.
- If you maintain dashboards/alerts for this CLI, record where they live and who receives notifications.
- Ensure at least one responder other than the releaser can follow the incident checklist (or equivalent runbook) for your deployment.
