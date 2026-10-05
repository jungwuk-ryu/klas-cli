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
- `warnings`: non-fatal issues or partial failures, always check `ok` first
- Fan-out rule: for commands that query multiple courses, return `ok=true` with usable `data` plus `warnings` if at least one course succeeds; if all selected courses fail, return a top-level structured error (`ok=false`)
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

## Course detail payloads

`notices show <board_no> --course <course>` returns the same normalized notice fields as `notices list`, plus `content_html`, `content_text`, and `attachments`. The exact course is required because board numbers are scoped to a course. A missing notice returns `NOTICE_NOT_FOUND` with exit code `66`.

`tasks show <task_no> [--course <course>]` preserves `report_html`, `report_title`, and `submission_text`, and adds `report_text`, `attachments` (instructor files), and `submission_attachments` (the student's submitted files). Reuse the exact `course_id` from the list; a number shared across courses returns `AMBIGUOUS_INPUT` without a course filter.

The body text is derived from the editor HTML with paragraphs, breaks, list items, code indentation, and link destinations retained. The original HTML is also available for consumers that need full formatting. No scripts are executed. Attachment content is downloaded as bytes; the CLI does not extract text from PDFs, images, archives, or other files.

Each attachment is normalized as:

```json
{
  "file_name": "instructions.pdf",
  "size_bytes": 1234,
  "local_path": null
}
```

- `file_name` and `size_bytes` can be null if KLAS omits that metadata.
- Detail attachment lists are empty when no reference exists, or when no files were returned; a reference that resolves to no files also produces a warning.
- A null attachment list means unavailable because listing failed, or because a notice reports files without supplying their attachment reference. Both cases include a warning. List commands leave bodies and attachment lists null because they do not load details.
- Without `--download-dir`, `local_path` is null and no bytes are downloaded.
- With `--download-dir <directory>`, successful downloads have an absolute `local_path` beneath a unique `klas-...` child directory. Instructor and submission files occupy separate subdirectories, and sanitized names receive a number prefix. Existing files are preserved.
- Listing or download failures retain a successful body response with sanitized `warnings`. Download warnings identify the attachment group and its one-based position. A failed download leaves that file's `local_path` null. Check warnings and paths before assuming all attachments were saved.
- `--dry-run` validates the arguments without touching KLAS or creating directories. It does not check destination permissions or attachment availability.
- `--fields` filters the response only; it does not suppress the requested download side effect.

Private downloaded attachments should stay outside version control. No file identifiers, raw upstream records, or session material are exposed in attachment objects.

## Stable error codes in v1

- `AUTH_REQUIRED`
- `AUTH_INVALID_CREDENTIALS`
- `AUTH_EXPIRED`
- `NETWORK_ERROR`
- `COURSE_NOT_FOUND`
- `TASK_NOT_FOUND`
- `NOTICE_NOT_FOUND`
- `AMBIGUOUS_INPUT`
- `USAGE_ERROR`
- `UNSUPPORTED_FEATURE`
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
