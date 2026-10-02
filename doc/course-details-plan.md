# Course bodies and attachments

## Goal and acceptance criteria

Students can select a course, list its notices and tasks, read one item's body in text or JSON, and save its attachments with an explicit download option. Runtime schema, help, docs, and deterministic tests describe the same behavior.

## Scope

Add `notices show <board_no> --course <selector>` and extend `tasks show <task_no> [--course <selector>]`. Both accept `--download-dir <directory>`. Default detail reads list attachment metadata without saving files. Task detail distinguishes instructor attachments from submission attachments. Standalone file indexing, attachment content conversion, student submissions, and other remote mutations remain outside this change.

## Public contract

Keep the JSON envelope at schema version `1.0` and preserve existing fields. Add `report_text`, `attachments`, and `submission_attachments` to task data. Notice detail includes `content_html`, `content_text`, and `attachments`. Attachment objects contain `file_name`, `size_bytes`, and `local_path`. Null lists mean unavailable or not loaded; empty lists mean no attachments were returned. Attachment failures preserve the body and appear in sanitized warnings. A missing notice returns `NOTICE_NOT_FOUND`.

## Implementation surfaces

Only `klas-cli` needs changes: normalized models, SDK service adapter, detail command handlers, runtime schema, body renderer, download storage, tests, README, JSON contract, decision log, release checklist, and the local agent skill. The hosted `klasflow` 1.2.0 public course/learning/notice/file APIs supply the existing capability; no SDK, transport, or auth changes are planned.

## Validation

Use the package's required Dart SDK, run `dart run tool/check_all.dart`, and compile the executable to the ignored build directory. Tests cover course scoping, notice existence and list-bound detail context, task ambiguity, HTML text conversion, both attachment groups, authenticated byte downloads, missing attachments, sanitized partial failures, unsafe filenames, existing files, schema/fields, dry-run, and parsing before network or disk access.

## Privacy and file handling

Mock HTTP is the default. If live evidence is needed, the user authorizes Chrome login and read-only verification. No credentials or live attachments enter repository fixtures or logs. Downloads use a unique child directory under the explicitly supplied destination; names are sanitized and numbered to prevent traversal and collisions. Dry-run does not access KLAS or create directories. No release publishing is authorized by this task.

## Completed validation

`dart run tool/check_all.dart` passed with Dart 3.11.1: static analysis reported no issues, the full suite passed 75 tests, installer checks passed, and the publish dry-run reported zero warnings. The executable compiled to `build/klas.exe`; its notice detail help/schema and both detail dry-runs passed without creating a destination directory. Authenticated downloads were verified with mock HTTP and temporary files. No live account verification was performed.
