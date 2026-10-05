---
name: klas-student-cli
description: Use the local KLAS Dart CLI to answer read-only student questions about auth, courses, task and notice bodies and attachments, timetable, and calendar. Prefer JSON output.
compatibility: opencode
metadata:
  audience: personal-agent
  domain: university-klas
---

# klas-student-cli

Use this skill when a student or agent needs read-only KLAS information from the local `klas` CLI.

## When to use

- remaining assignments
- details for one task
- current course list
- course notices
- this week's schedule
- monthly calendar schedule
- auth readiness for the CLI

## Auth guidance

Install the CLI first when `klas` is not already available:

The raw GitHub URLs intentionally point at `main` as the stable release channel, while day-to-day development happens on `develop` and short-lived branches.

```bash
curl -fsSL https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.sh | bash
```

```powershell
iwr -useb https://raw.githubusercontent.com/jungwuk-ryu/klas-cli/main/install.ps1 | iex
```

Prefer reusable local auth session first:

```bash
klas auth login
```

For bot-driven login without shell `export`, use stdin JSON:

```bash
printf '{"id":"<id>","password":"<password>"}' | \
  klas auth login --stdin-json --format json
```

Environment variables remain a fallback option:

```bash
export KLAS_ID="<id>"
export KLAS_PASSWORD="<password>"
```

If neither local session nor environment variables are available and the user is in an interactive terminal, `klas` can prompt for credentials in text mode. Do not expect prompt-driven auth in JSON automation.

If a JSON command returns `AUTH_CAPTCHA_REQUIRED` (exit code 65), ask the human to run `klas auth login` in an interactive terminal with text output. The CLI opens the current captcha image and accepts the digits, including leading zeros. Let the human provide the answer; do not guess or automatically solve the captcha. After successful login, retry the original JSON command. Captcha cancellation and retry exhaustion preserve saved credentials. `--stdin-json`, JSON output, and `auth status` do not open images or prompt for captcha.

## Default rule

Prefer `--format json` for any agent workflow.

When you only need a subset of fields, add `--fields` to reduce context usage.

Use `schema` to inspect the command contract at runtime before guessing flags, subcommands, or output fields.

## Execution rule

When `klas` is installed globally, the current working directory does not matter.

If you are using `dart run` from a checkout instead, run commands from that repository root.

## Common commands

### Check auth

```bash
klas --format json auth status
```

### Inspect a command contract

```bash
klas --format json schema tasks list
```

### List courses

```bash
klas --format json courses list
klas --format json --fields course_id,title courses list
```

### Show one course

```bash
klas --format json courses show --course "CSE101"
```

### List tasks

```bash
klas --format json tasks list
klas --format json --fields course_id,task_no,title tasks list
```

### Show one task

```bash
klas --format json tasks show 12 --course "CSE101"
klas --format json --fields report_text,attachments,submission_attachments tasks show 12 --course "CSE101"
```

### List notices

```bash
klas --format json notices list
```

### Read one notice and save attachments

```bash
klas --format json notices show 7 --course "CSE101"
klas --format json notices show 7 --course "CSE101" --download-dir ./downloads
klas --format json tasks show 12 --course "CSE101" --download-dir ./downloads
```

Use `content_text` for notice bodies and `report_text` for task instructions. Original HTML remains available as `content_html` or `report_html`. `attachments` contains notice or instructor files; task `submission_attachments` contains the student's submitted files. Each file has `file_name`, `size_bytes`, and `local_path`. Only add `--download-dir` when the user needs local attachment files. After downloading, open or inspect the successful `local_path` with a suitable file viewer; the CLI does not convert binary file contents to text.

Downloads occupy a unique child directory and do not overwrite existing files. Check `warnings` and each `local_path` for partial failures. Null attachment lists mean unavailable; empty lists mean no returned files. List commands do not load bodies or attachments. `--dry-run` does not download or create directories, and `--fields` only shapes output, so it does not suppress downloads. Keep private attachments outside version control.

### Filter notices or tasks to one course

```bash
klas --format json tasks list --course "CSE101"
klas --format json notices list --course "자료구조"
```

### Validate locally before a read-only call

```bash
klas --format json --dry-run tasks show 12 --course "CSE101"
```

### Timetable and calendar queries

```bash
klas --format json timetable week
klas --format json calendar month
klas --format json --fields title,starts_at,ends_at,status calendar month --year 2026 --month 10
```

## Interpretation rules

- `tasks list` is the truthful replacement for "remaining assignments" in v1. There are no `tasks due` / `tasks overdue` commands in v1, so do not invent overdue semantics; instead, interpret `due_at` from `tasks list` and clearly label any client-side filtering as derived.
- Reuse `course_id` from `tasks list` when a follow-up `tasks show` call needs `--course`.
- Reuse `course_id` and `board_no` from `notices list` for `notices show`; `--course` is required for notice detail.
- `timetable week` is timetable-based recurring class data.
- Use `calendar month` for monthly assignments and academic schedules. It includes events overlapping the selected month and preserves the full period in `starts_at` and `ends_at`, even across month boundaries.
- Use those full timestamps when reporting a period. Unknown dates are null, and date-only values use midnight; do not invent an end time or replace an event's original month with the requested month.
- there is no mixed `today` command in the canonical surface.
- `warnings` in the JSON envelope matter. They can indicate partial failures during course fan-out.
- `schema` is the preferred way to discover supported flags and normalized output fields at runtime.
- `--fields` only trims top-level keys in the normalized JSON `data` payload.
- `--dry-run` validates local inputs without contacting KLAS.
- Do not pass course selectors containing `?`, `#`, or `%`.

## Do not assume

- no `tasks due` command in v1
- no `tasks overdue` command in v1
- no `progress` commands in v1
- no standalone `files` commands; list and save attachments through `tasks show` or `notices show`
- no student IDs in command output
