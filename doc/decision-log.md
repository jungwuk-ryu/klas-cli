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

- Chosen option: ship `auth login|status|logout`, `me profile`, `courses list|show`, `tasks list|show`, `notices list`, `timetable week`, and `calendar month` in v1.
- Alternatives considered: keeping a mixed `schedule` family; preserving `today` as a derived command; nesting timetable and calendar under one `schedule` group.
- Why this is better here: `timetable week` maps to the verified semester timetable API, and `calendar month` maps directly to the verified monthly schedule table API, so the command tree now follows real data domains instead of mixing them behind one noun.
- Remaining risk: the CLI no longer offers a blended daily view, so users who want a combined “today” view must query timetable and calendar separately.

## 1.0.0 release scope hardening

- Chosen option: treat `1.0.0` as a scope-hardening release that freezes the already shipped reduced surface and explicitly defers unverified or misleading breadth (such as `tasks due|overdue`, `notices show`, `progress`, and `files`).
- Alternatives considered: expanding the command tree to include all requested convenience commands; shipping placeholder commands that return partial or best-effort data; documenting a broader surface than the runtime actually supports.
- Why this is better here: this CLI is agent-first and its documented output is a public contract, so `1.0.0` must prioritize trust, stable automation, and truthful scope over breadth; deferring ambiguous domains (notably progress semantics and file handling) avoids shipping commands that look complete but are not reliably backed by `klasflow`.
- Remaining risk: users will still want overdue/progress/files workflows, so the project must either validate upstream capability and implement them with a clear contract later, or continue to be explicit about the gap.

## Session persistence scope

- Chosen option: keep the local reusable daemon session, but back it with durable encrypted credentials so the daemon can be recreated after reboot or local process loss.
- Alternatives considered: daemon-only ephemeral reuse; env-only auth; plaintext password persistence.
- Why this is better here: it preserves prompt-free UX across CLI invocations and machine restarts while avoiding plaintext credential storage on disk.
- Remaining risk: cross-platform security quality still depends on local platform capability, so some environments may fall back to encrypted files rather than an OS credential store.

## Auth recovery evidence

- Chosen option: verify durable credential-backed daemon restoration plus environment fallback for ordinary commands.
- Alternatives considered: relying only on environment variables; requiring explicit re-login after every reboot.
- Why this is better here: ordinary commands can silently restore reusable auth after daemon death or reboot while environment variables remain a fallback path.
- Remaining risk: recovery still depends on local secure-storage availability and correct protection of local state directories.

## Durable auth storage backend

- Chosen option: store runtime session metadata separately from durable credentials, protect durable credentials with encrypted local files, and prefer OS-backed key protection when available.
- Alternatives considered: platform-specific native helpers only; file-only plaintext storage; no persistent credential layer.
- Why this is better here: this keeps the implementation inside the Dart CLI, survives reboot, avoids plaintext secrets, and still degrades gracefully on headless or minimal systems.
- Remaining risk: macOS/Linux keychain tooling can vary by environment, so the encrypted-file fallback remains part of the supported compatibility story.

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
