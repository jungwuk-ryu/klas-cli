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
