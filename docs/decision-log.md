# Decision Log

## Dependency strategy for `klasflow`

- Chosen option: `git` dependency pinned to the upstream repository.
- Alternatives considered: local `path` dependency; vendoring/copying upstream code.
- Why this is better here: this repo is standalone and currently does not include a sibling `klasflow` checkout, while upstream explicitly supports git usage and is not published on pub.dev.
- Remaining risk: upstream `master` can change; pinning should use a specific commit rather than a floating branch when implementation starts.

## External CLI contract boundary

- Chosen option: agent-safe normalized CLI contract over a thin adapter to `klasflow` public APIs.
- Alternatives considered: exposing upstream objects directly; mirroring every upstream feature.
- Why this is better here: upstream is still evolving, while the CLI contract must stay stable for both humans and AI agents.
- Remaining risk: some upstream models are still semi-raw, so normalization work must be explicit per command.

## Authentication model

- Chosen option: ordinary commands perform auth/session readiness checks and attempt safe silent recovery.
- Alternatives considered: separate health-check-first workflow; login-only manual recovery.
- Why this is better here: the project contract requires auth-aware ordinary commands and clean machine-readable stdout.
- Remaining risk: silent recovery boundaries must avoid corrupting JSON stdout or leaking sensitive material.

## Progress feature scope

- Chosen option: defer `progress` from v1.
- Alternatives considered: inventing a percentage-based progress score; shipping a partially defined record passthrough.
- Why this is better here: upstream exposes learning status and realtime progress records, but not a clearly documented public aggregate progress API.
- Remaining risk: user expectations for learning progress remain unmet until upstream capability or a well-documented derived model is verified.

## Trimmed command surface

- Chosen option: ship `auth login|status|logout`, `me profile`, `courses list|show`, `tasks list|show`, `notices list`, and `schedule today|week|next` in v1.
- Alternatives considered: shipping the full target surface immediately; deferring schedule as well.
- Why this is better here: these commands map cleanly to verified public `klasflow` APIs without guessed joins or speculative semantics.
- Remaining risk: `schedule` merges recurring timetable data with calendar-style schedule data and needs explicit precedence and warning behavior.

## Session persistence scope

- Chosen option: create a reusable local auth session managed by the CLI, with credentials held in a local in-memory daemon and only connection metadata written to disk.
- Alternatives considered: storing raw passwords locally; inventing unsupported full session restore via `klasflow`; env-only auth.
- Why this is better here: it gives cross-process reusable login without requiring shell `export`, while avoiding plaintext password persistence on disk.
- Remaining risk: the reusable session lasts only while the local daemon is alive and is still trusted-user local state rather than a hardened secret-store integration.

## Auth recovery evidence

- Chosen option: verify daemon-backed reusable auth plus environment fallback for ordinary commands.
- Alternatives considered: claiming opaque session restoration; relying only on environment variables.
- Why this is better here: ordinary commands can reuse local auth state without shell exports, while environment variables remain available as a fallback path.
- Remaining risk: the reusable daemon session is local-process infrastructure, not OS keychain integration.

## Agent runtime introspection and response shaping

- Chosen option: add a local `schema` command plus global `--fields` and `--dry-run` flags over the existing normalized CLI contract.
- Alternatives considered: relying only on static docs; exposing raw upstream payload masks directly; adding MCP before the local CLI contract was self-describing.
- Why this is better here: the current repo already has a stable normalized JSON envelope, so the smallest truthful agent-first improvement is runtime command introspection, context-window control, and local validation without expanding protocol scope.
- Remaining risk: `--fields` trims normalized CLI output rather than upstream payloads, so it reduces response size but is not a substitute for upstream API field masks.

## Adversarial input hardening

- Chosen option: reject control characters in agent-supplied strings and reject `?`, `#`, `%` in course selectors.
- Alternatives considered: permissive passthrough with downstream escaping only; broad regex lockdown for all identifiers.
- Why this is better here: this CLI already uses exact-match selectors, so blocking embedded query fragments and pre-encoded values directly addresses likely agent hallucination patterns without breaking truthful human inputs like Korean course titles.
- Remaining risk: hardening is currently focused on existing selector/auth entry points rather than hypothetical future commands.
