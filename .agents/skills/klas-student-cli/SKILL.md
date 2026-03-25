---
name: klas-student-cli
description: Use the local KLAS Dart CLI to answer read-only student questions about auth, courses, tasks, notices, timetable, and calendar. Prefer JSON output.
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
```

### List notices

```bash
klas --format json notices list
```

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
klas --format json calendar month --year 2026 --month 3
```

## Interpretation rules

- `tasks list` is the truthful replacement for "remaining assignments" in v1. There are no `tasks due` / `tasks overdue` commands in v1, so do not invent overdue semantics; instead, interpret `due_at` from `tasks list` and clearly label any client-side filtering as derived.
- Reuse `course_id` from `tasks list` when a follow-up `tasks show` call needs `--course`.
- `timetable week` is timetable-based recurring class data.
- `calendar month` is the direct monthly schedule table view.
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
- no `files` commands in v1
- no `notices show` in v1
- no student IDs in command output
