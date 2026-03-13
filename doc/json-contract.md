# JSON Contract

## Envelope

Every JSON command response uses this top-level shape:

```json
{
  "ok": true,
  "schema_version": "1.0",
  "command": "courses list",
  "data": [],
  "meta": {},
  "warnings": []
}
```

Error responses replace `data` with `null` and include an `error` object:

```json
{
  "ok": false,
  "schema_version": "1.0",
  "command": "me profile",
  "data": null,
  "error": {
    "code": "AUTH_REQUIRED",
    "message": "Authentication is required for this command.",
    "retryable": false,
    "hint": "Set KLAS_ID and KLAS_PASSWORD or run the command in an interactive terminal.",
    "details": {}
  },
  "meta": {},
  "warnings": []
}
```

## Field rules

- `ok`: boolean success flag
- `schema_version`: currently `1.0`
- `command`: stable command identity, such as `tasks list`
- `data`: normalized CLI-facing payload
- `meta`: command-level metadata such as counts or execution basis
- `warnings`: partial-failure or caution messages
- `error.code`: machine-actionable stable string
- `error.message`: human-readable description
- `error.retryable`: whether retrying may succeed
- `error.hint`: optional recovery guidance
- `error.details`: optional structured details map

## Agent runtime controls

- `schema` returns runtime command metadata, including options, arguments, output fields, and whether `--dry-run` or `--fields` are supported.
- `--fields` keeps only requested top-level keys inside `data` and records the applied list in `meta.fields`.
- `--dry-run` returns a success envelope without calling KLAS. The response includes `data.validated=true` and `meta.dry_run=true`.

## Input hardening rules

- Course selectors reject control characters plus `?`, `#`, and `%`.
- `auth login --stdin-json` rejects empty strings and control characters in `id` and `password`.
- `--fields` only accepts comma-separated top-level field names using lowercase letters, digits, and underscores.

## Stable error codes in v1

- `AUTH_REQUIRED`
- `AUTH_INVALID_CREDENTIALS`
- `AUTH_EXPIRED`
- `NETWORK_ERROR`
- `COURSE_NOT_FOUND`
- `TASK_NOT_FOUND`
- `AMBIGUOUS_INPUT`
- `USAGE_ERROR`
- `INTERNAL_ERROR`

## stdout and stderr rules

- In JSON mode, `stdout` contains only the JSON envelope.
- Interactive prompts and human diagnostics must go to `stderr`.
- The CLI never mixes pretty text into JSON stdout.

## Auth notes

- `auth login --stdin-json` reads one JSON object from stdin with `id` and `password` string fields.
- The CLI may create a reusable local auth session for later invocations.
- Sensitive credentials are never included in the documented JSON envelope.
- Durable local auth may be stored through an OS credential store or an encrypted local file, while runtime session metadata remains local CLI state.

## Privacy rules

- No passwords
- No cookies
- No raw session material
- No student IDs in command output
- No raw upstream payload passthroughs
