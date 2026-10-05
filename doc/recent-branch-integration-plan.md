# Recent branch integration, 2026-10-05

## Goal and acceptance criteria

Integrate every remote work branch whose latest commit falls within the last
seven days into each repository's `develop`, push the verified result, and remove
the fully integrated work branches locally and remotely. Use the rolling window
starting at 2026-09-28 03:24:49 UTC, based on the committer date of each remote tip.
Preserve release branches and work branches outside this window.

## Scope and inputs

The `klas-flow` branch `codex/feat-team-projects` at `04c81a5` is already an
ancestor of `develop` at `e1fc9c7`; it requires verification and cleanup rather
than another merge.

The `klas-cli` integration starts from remote `develop` at `b0352fc` and merges
these captured tips in dependency order, retaining each branch's merge history:

| Branch | Captured tip | Behavior |
|---|---|---|
| `codex/feat-course-details` | `28c8d57` | Course bodies and attachment downloads |
| `codex/feat-captcha-login` | `7d9a6ff` | Human captcha continuation and SDK pin |
| `codex/fix-windows-installer` | `0435efd` | PowerShell 5.1 installation and Dart selection |
| `codex/fix-windows-auth-session` | `38ca652` | Windows reusable authentication process |
| `codex/fix-monthly-calendar` | `381cc4a` | Monthly calendar dates and full event periods |

Keep SDK `master`, CLI `main`, and the older CLI `fix/issue-2-tasks-show-help`
branch. No release promotion, hosted publishing, new commands, or live student
actions are part of this integration.

## Public behavior and changed surfaces

Retain the public APIs, commands, typed outputs and error semantics introduced
by the work branches. Resolve overlapping README, agent guidance, release docs
and workflow changes while preserving the existing develop-first policy and
the newer feature documentation. Preserve the verified SDK dependency pin;
changing the upstream version is outside this merge unless compatibility
validation proves it necessary.

## Validation

Run `dart run tool/check_all.dart` in both repositories with Dart 3.11.1. This
covers SDK analysis, tests and release safety; the CLI gate also covers schemas,
dry-run behavior, installer contracts and package dry-run checks. Build the
merged CLI as a Windows executable and exercise its help and auth/calendar
schemas. Verify that every captured branch tip is an ancestor of the final
integration commit. Confirm GitHub CI before removing source branches.

## Push and cleanup safety

Fast-forward each `develop` only after validation. Use normal pushes for
integration branches. Recheck remote tips before cleanup and use explicit
leases tied to the captured commit for remote deletions. Delete local work
branches with Git's merged-branch checks, and leave other checkouts untouched.
Do not modify account authentication, solve a captcha, submit attendance or
record video progress for this repository-integration task. Keep private
artifacts and credentials out of commits and output.

## Local validation results

All five CLI tips are ancestors of merge commit `cb311cf`; the SDK team-project
tip is already an ancestor of `e1fc9c7`. The only manual merge resolutions were
the additive `.gitignore` entries and decision-log sections. Comparison with the
latest CLI work branch confirms that its implementation is preserved along
with the existing develop workflow and operational documentation.

On 2026-10-05, both `dart run tool/check_all.dart` gates passed with Dart 3.11.1.
The SDK passed 227 tests and its prepublish safety check. The CLI passed 94
tests, installer contracts, schemas, dry-run checks and package dry-run validation.
The package dry-run reported zero warnings and the existing dependency-override
hint; hosted release preparation remains a separate release task.

The merged CLI compiled successfully as a Windows executable. Its help and
JSON schemas for `auth login`, `calendar month`, `notices show` and `tasks show`
all succeeded without accessing a live account. SDK GitHub CI at `e1fc9c7` has
already passed. Push the CLI integration and wait for its CI before cleanup.
