# Decision Log

## Dependency strategy for `klasflow`

- Chosen option: hosted pub.dev dependency on `klasflow`.
- Alternatives considered: local `path` dependency; git pinning to the upstream repository; vendoring/copying upstream code.
- Why this is better here: the package is now published on pub.dev, so hosted versioning gives this standalone CLI a simpler install path and aligns dependency resolution with semantic versions instead of repository commits.
- Remaining risk: upstream public releases can still change behavior across versions, so CLI verification should stay pinned to the published version range and be revalidated when bumping major or minor versions.

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

## One-line installer strategy

- Chosen option: ship standalone `install.sh` and `install.ps1` scripts that bootstrap a user-local Dart SDK only when needed, then install `klas_cli` from pub.dev with `dart pub global activate klas_cli --overwrite`.
- Alternatives considered: requiring a preinstalled Dart SDK; requiring Homebrew/apt/Chocolatey as the main path; cloning the repository and building locally.
- Why this is better here: the package is already published on pub.dev, while the product requirement is a one-line installer that works even on machines without Dart.
- Remaining risk: the installer pins a tested Dart SDK version, so the scripts must stay aligned with future SDK floor changes in `pubspec.yaml`.

## Post-install login handoff

- Chosen option: verify `klas --help` and then run `klas auth login` immediately when interactive input is available, while printing the exact next command in non-interactive contexts.
- Alternatives considered: stopping after installation; forcing environment-variable login only; adding an installer-only command inside the CLI.
- Why this is better here: it satisfies the request to continue into login without changing the CLI command surface, and it handles the `curl ... | bash` stdin redirection case truthfully.
- Remaining risk: interactive login still depends on a real terminal or pre-supplied `KLAS_ID` and `KLAS_PASSWORD`.
