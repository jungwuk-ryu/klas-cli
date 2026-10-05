# Windows PowerShell installer compatibility

## Goal and scope

Make the existing installer run under Windows PowerShell 5.1 and choose a Dart
SDK satisfying the CLI's 3.11.1 minimum. Keep pub.dev activation and interactive
login handoff. Monthly calendar behavior is covered by a separate change.

## Implementation and decisions

Use Windows' native architecture environment variables, preferring the native
architecture when PowerShell runs under emulation. Avoid unavailable .NET
`RuntimeInformation` properties. Keep PATH entries as arrays under strict mode
and move the chosen SDK ahead of an older Flutter-provided Dart. Stop if package
activation or the executable's help check fails.

## Validation and constraints

Run deterministic PowerShell 5.1 function tests in child processes for x64,
ARM64/emulation, single-entry PATH, existing lower-priority SDK paths, and the
3.10/3.11 version decision. Run `dart run tool/check_all.dart`. The tests must
not download/install packages, change the user's persistent PATH, or log in.
Commit and push the installer fix independently from the calendar correction.

## Completed validation

The full `tool/check_all.dart` gate passed with 90 tests. All six installer tests
passed, including three real Windows PowerShell 5.1 child-process checks.
Package dry-run reported zero warnings and the existing SDK override hint.
