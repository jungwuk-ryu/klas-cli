## 1.1.0 (Unreleased)

- Continue interactive text logins through numeric captcha using the `klasflow` 1.3.0 challenge callback. Open temporary images, preserve leading zeros, refresh rejected answers up to three times, and clean up images after input.
- Add `AUTH_CAPTCHA_REQUIRED` for captcha requests, cancellation, or retry exhaustion. JSON/stdin JSON and noninteractive commands remain prompt-free, and captcha errors preserve stored auth.

- Add course-scoped `notices show` with notice bodies in text and JSON.
- Show task instructions and separate instructor/submission attachment lists in `tasks show`.
- Add `--download-dir` to both detail commands for authenticated attachment downloads with safe filenames and preserved existing files.
- Report attachment failures as sanitized warnings while retaining readable bodies and successful downloads.
- Update runtime schema, command help, usage docs, and agent guidance for the detail workflow.

## 1.0.0

- Freeze the shipped command surface and `schema` output as the stable public contract.
- Lock the JSON envelope and options (`--format json`, `--fields`, `--dry-run`), including strict stdout/stderr separation.
- Tighten warning and error behavior with stable, machine-actionable error codes and sanitized messages.
- Add deterministic auth and session coverage, including durable credential reuse, session recovery, and expired-session fallback.
- Harden fan-out list semantics (`tasks list`, `notices list`): partial failures become `warnings`, all-fail escalates to a structured error.
- Strengthen release readiness with `tool/check_all.dart` gating plus baseline, release, and operations docs.

## 0.2.0

- Make local auth more durable with stored credential reuse, automatic session recovery, and safer fallback from invalid saved session state.
- Add regression coverage for auth persistence and refresh the public and agent-facing docs around the installed CLI flow.
- Polish release usability with hosted `klasflow` dependency setup, one-line installers, and small `courses show` and `tasks show` help fixes.

## 0.1.0

- Initial version.
