# AGENTS.md

## Project purpose

This repository is a standalone Dart CLI built on top of `klasflow`.
Its job is to turn the upstream high-level KLAS SDK into a stable command-line interface that works well for:

1. human Kwangwoon University students, and
2. AI agents that need predictable commands and structured output.

This is an **agent-first CLI**, not a low-level SDK clone.
The public contract is the CLI command surface plus its documented JSON/text outputs.

## Product principles

- Prefer **fewer correct commands** over a broad but speculative surface.
- Default to **read-only** student flows.
- Treat machine-readable CLI output as a public API.
- Keep the CLI usable by humans without sacrificing agent reliability.
- Recover auth/session state automatically where safe.
- Keep stdout clean for data and stderr clean for diagnostics.

## Upstream boundary: `klasflow`

`klasflow` is the upstream SDK and source of truth for KLAS access.
Use the **public high-level API** rather than re-implementing low-level endpoint details.
Do not expose or document:

- endpoint ID strings
- raw payload maps
- private reverse-engineering notes
- session internals beyond what a safe CLI needs

Before adding a CLI feature, verify it against actual `klasflow` capability.
If the upstream capability is incomplete, either:

- implement a clearly documented derived view using verified upstream data, or
- defer the feature and document the gap honestly.

## Command design contract

The target command tree is:

- `klas auth login|status|logout`
- `klas me profile`
- `klas courses list|show`
- `klas tasks list|due|overdue|show`
- `klas notices list|show`
- `klas timetable week`
- `klas calendar month`
- `klas progress by-course|show`
- `klas files list|download`

Adjust only when correctness requires it.
If you remove or narrow a command, explain why in docs and in the final report.

### Command style

- Prefer explicit names and flags.
- Avoid clever aliases unless they are clearly worth the ambiguity cost.
- Make top-level help and subcommand help genuinely informative.
- Design commands around stable information domains, not natural-language intent parsing.

## Output contract

Every command must support a machine-readable mode.
A stable JSON envelope is preferred:

```json
{
  "ok": true,
  "schema_version": "1.0",
  "command": "tasks due",
  "data": [],
  "meta": {},
  "warnings": []
}
```

Errors must be structured and machine-actionable.
Use stable string codes such as:

- `AUTH_REQUIRED`
- `AUTH_EXPIRED`
- `NETWORK_ERROR`
- `COURSE_NOT_FOUND`
- `TASK_NOT_FOUND`
- `UNSUPPORTED_FEATURE`
- `INTERNAL_ERROR`

### stdout / stderr rules

- In machine-readable mode, stdout contains only the structured result.
- Human guidance, prompts, auth explanations, warnings, and debug logs go to stderr.
- Never mix pretty text into JSON stdout.

## Authentication and session rules

Normal commands are responsible for session readiness.
Do not make users run a health-check command as the ordinary path.

Preferred behavior:

1. reuse cached session data when valid
2. attempt silent session refresh / re-auth when safe
3. request interactive login only when required
4. return structured auth errors when recovery cannot proceed automatically

Never print secrets.
Never persist passwords insecurely.
Mask sensitive material in logs and failures.

## Safety and privacy

This project handles university account data.
Treat the following as sensitive:

- passwords
- session cookies / tokens
- student IDs
- downloaded private attachments
- screenshots or logs containing personal data

Rules:

- never commit secrets or private data
- never add fixtures containing real credentials
- keep live verification read-only by default
- do not implement state-changing student actions unless explicitly requested and justified

## Architecture expectations

Keep the codebase layered.
A good default structure is:

- `bin/` — executable entrypoints
- `lib/src/commands/` — command handlers and argument parsing
- `lib/src/domain/` — normalized CLI-facing models
- `lib/src/services/` — orchestration of upstream SDK calls
- `lib/src/auth/` — session store, login flow, auth middleware
- `lib/src/output/` — text renderers and JSON envelope serializers
- `lib/src/errors/` — error mapping and exit code policy
- `test/` — unit and integration tests
- `doc/` — contract docs, decision log, usage guides
- `.agents/skills/` or `.opencode/skills/` — project-local agent skills

Do not let raw upstream SDK objects leak directly into the external CLI contract.
Normalize them first.

## Progress feature rule

`progress` is easy to fake and hard to define.
Treat it as high-risk.
Only ship it after verifying whether `klasflow` exposes enough reliable information.
If you compute a derived progress value, document:

- data sources used
- formula or aggregation method
- known blind spots
- whether it is approximate or authoritative

A narrower truthful `progress` command is better than a misleading full score.

## Planning and decision-making

The user wants careful, self-critical work.
Do not rush from requirements to implementation.
For each major design choice, capture in `doc/decision-log.md`:

- chosen option
- alternative options considered
- why the winner is better here
- residual risk

Examples of major decisions:

- path dependency vs git dependency for `klasflow`
- command-runner framework choice
- session persistence strategy
- JSON contract shape
- whether and how to implement `progress`

## Validation requirements

Every meaningful code change should maintain a working local validation path.
At minimum, keep these areas covered when relevant:

- static analysis
- unit tests
- command parsing tests
- JSON contract tests
- auth/session behavior tests
- text rendering tests for important commands

Prefer deterministic tests.
Use live account checks only when absolutely necessary and keep them read-only.

Use `dart run tool/check_all.dart` as the CI-aligned baseline quality gate.
For rollout criteria and release policy, follow:

- `doc/engineering_quality_baseline.md`
- `doc/release_checklist.md`

## Documentation requirements

When the external CLI behavior changes, update:

- `README.md`
- command examples
- JSON contract / error code docs
- agent integration docs
- any skill docs that depend on command names or output structure

Docs must match shipped behavior.

## Agent integration requirement

This repository should include at least one local skill that helps AI agents use the CLI correctly.
That skill should explain how to answer student questions such as:

- remaining assignments
- overdue assignments
- current or upcoming schedule
- course notices
- course progress / learning status

The skill should prefer CLI calls with machine-readable output.

## Completion gate

Do not declare the task complete until all of the following are true:

1. the repository builds as a Dart CLI
2. the selected command surface is implemented or honestly narrowed
3. core commands have working help text
4. structured output and error mapping exist
5. auth/session behavior is implemented
6. tests pass
7. README and agent-facing docs are accurate
8. the local skill exists
9. final verification cites concrete evidence from files and commands

## Working style

Use positive, direct instructions.
Work from evidence.
Inspect before assuming.
Prefer coherent v1 scope over sprawling unfinished ambition.
