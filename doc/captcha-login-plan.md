# Numeric captcha login

## Goal and scope

Continue authentication when KLAS asks for a numeric captcha. A human sees the current image and supplies its digits, after which the same SDK login continues. Support text-mode login and ordinary read commands, preserving the JSON envelope and saved credentials. No automatic solving, persisted challenge state, Chrome cookie import, or deliberate live lockout/captcha triggering is included.

## Contract and implementation

Use the public `KlasClient.login(onCaptcha: ...)` API from `klasflow` 1.3.0. Place temporary-image handling in `lib/src/auth/captcha_prompter.dart` and attach it in `KlasflowService` only when prompting is allowed. Keep stdout reserved for results and put image paths/prompts on stderr. Open an image viewer when available, allow a manual path fallback, accept numeric strings with leading zeros, and remove images after input or cancellation. On Unix, protect the temporary directory and file with owner-only permissions.

JSON, stdin JSON, noninteractive commands, and auth status do not request input. Captcha absence/cancellation/exhaustion maps to `AUTH_CAPTCHA_REQUIRED`, exit 65, with human recovery guidance. Authentication state is saved only after successful login and is not cleared for captcha errors.

## Surfaces and validation

Update service auth orchestration, command prompting policy, error mapping, runtime schema/help, README, JSON contract, agent skill, decision log, and changelog. Preserve the pre-existing course body and attachment work. Tests cover image lifecycle, leading zeros, local invalid input, viewer failures, login and normal commands, JSON and noninteractive errors, saved credential preservation, retry exhaustion, and stdin JSON prompting policy. Run `dart run tool/check_all.dart` and compile the executable.

## Release constraints

Source checkouts and CI use the root pubspec's Git override pinned to the verified, pushed SDK commit. The lockfile records that same revision; no sibling filesystem path or local override is required. Release must publish SDK 1.3.0 first, remove the Git override, regenerate the hosted lockfile, and rerun the full gate. Package publishing is separate from this commit/push task. Use only synthetic credentials and image fixtures in automated checks.

## Completed validation

On 2026-10-02, the full `dart run tool/check_all.dart` gate passed against the pinned remote SDK with no local override: analysis, 87 tests, runtime schema/dry-run checks, installer tests, and publish dry-run. Package validation reported zero warnings and one development-override hint, which remains covered by the hosted release constraint above. The executable compiled and its help and notice-detail dry-run passed. The preceding course-detail commit was separately validated against hosted SDK 1.2.0 with 75 tests and no publish warnings.
