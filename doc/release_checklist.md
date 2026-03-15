# Release Checklist

## 1) Required quality gates

- Run `dart run tool/check_all.dart`.
- Confirm CI passes on the release commit (`.github/workflows/ci.yml`).

## 2) Contract and docs consistency

- Verify `README.md` command examples match actual behavior.
- Verify `doc/json-contract.md` matches the current envelope and error shape.
- Add release notes to `CHANGELOG.md`.

## 3) Packaging and installation

- Ensure `pubspec.yaml` version is updated for release.
- Run installer contract tests: `dart test test/installers/install_contract_test.dart`.
- Verify install scripts still point to the intended package/release channel:
  - `install.sh`
  - `install.ps1`

## 4) Manual smoke checks

- `dart run bin/klas.dart --help`
- `dart run bin/klas.dart --format json schema tasks list`
- `dart run bin/klas.dart --format json --dry-run tasks show 12 --course CSE101`
