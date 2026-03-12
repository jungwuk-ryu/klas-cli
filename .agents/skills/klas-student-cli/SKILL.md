---
name: klas-student-cli
description: Use the local KLAS Dart CLI to answer read-only student questions about auth, courses, tasks, notices, and schedule. Prefer JSON output.
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
- today's schedule
- this week's schedule
- next upcoming schedule item
- auth readiness for the CLI

## Auth guidance

Prefer reusable local auth session first:

```bash
dart run bin/klas.dart auth login
```

For bot-driven login without shell `export`, use stdin JSON:

```bash
printf '{"id":"<id>","password":"<password>"}' | \
  dart run bin/klas.dart auth login --stdin-json --format json
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

Use `schema` to inspect the command contract at runtime before guessing flags or output fields.

## Execution rule

These examples assume the current working directory is the repository root for this project.

If the agent is running elsewhere, execute from the repo root first:

```bash
cd /home/ubuntu/works/klas-cli
```

## Common commands

### Check auth

```bash
dart run bin/klas.dart --format json auth status
```

### Inspect a command contract

```bash
dart run bin/klas.dart --format json schema tasks list
```

### List courses

```bash
dart run bin/klas.dart --format json courses list
dart run bin/klas.dart --format json --fields course_id,title courses list
```

### Show one course

```bash
dart run bin/klas.dart --format json courses show --course "CSE101"
```

### List tasks

```bash
dart run bin/klas.dart --format json tasks list
```

### Show one task

```bash
dart run bin/klas.dart --format json tasks show 12 --course "CSE101"
```

### List notices

```bash
dart run bin/klas.dart --format json notices list
```

### Filter notices or tasks to one course

```bash
dart run bin/klas.dart --format json tasks list --course "CSE101"
dart run bin/klas.dart --format json notices list --course "자료구조"
```

### Validate locally before a read-only call

```bash
dart run bin/klas.dart --format json --dry-run tasks show 12 --course "CSE101"
```

### Schedule queries

```bash
dart run bin/klas.dart --format json schedule today
dart run bin/klas.dart --format json schedule week
dart run bin/klas.dart --format json schedule next
```

## Interpretation rules

- `tasks list` is the truthful replacement for "remaining assignments" in v1. Do not invent overdue semantics unless the CLI adds dedicated overdue commands later.
- `schedule week` is timetable-based recurring class data.
- `schedule today` and `schedule next` use a combined view of timetable and monthly schedule items.
- `warnings` in the JSON envelope matter. They can indicate partial failures during course fan-out.
- `schema` is the preferred way to discover supported flags and normalized output fields at runtime.
- `--fields` only trims top-level keys in the normalized JSON `data` payload.
- `--dry-run` validates local inputs without contacting KLAS.
- Do not pass course selectors containing `?`, `#`, or `%`.

## Do not assume

- no `progress` commands in v1
- no `files` commands in v1
- no `notices show` in v1
- no student IDs in command output
