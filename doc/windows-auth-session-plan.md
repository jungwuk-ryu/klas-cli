# Windows reusable auth session

## Goal and scope

Allow the existing local session daemon to start on Windows after a successful
KLAS login. Windows does not support Dart's SIGTERM watch. Preserve loopback
binding, bearer-token checks, credential persistence, and the explicit logout
endpoint. Unix SIGTERM cleanup remains available.

Allow up to 20 seconds for the source CLI's daemon to compile and start. On a
startup timeout, stop the child and clear stale metadata instead of waiting
indefinitely for an open stderr stream.

## Surfaces and validation

Guard the SIGTERM subscription in `lib/src/auth/session_manager.dart` and add a
real child-process lifecycle regression: startup, unauthorized rejection,
authorized status/credentials, logout, and metadata cleanup. Use synthetic
credentials and an isolated temporary directory with no KLAS requests or user
credential store access. Run auth tests and the full CLI quality gate before
committing this fix separately from calendar changes.

## Completed validation

The full quality gate passed with 91 tests. The regression uses the actual CLI
daemon through `LocalAuthSessionManager`, including source compilation startup,
credential reuse, unauthorized rejection, logout, and metadata cleanup on
Windows. Publish dry-run reported zero warnings and the existing override hint.
