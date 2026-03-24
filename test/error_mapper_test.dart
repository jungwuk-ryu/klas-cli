import 'package:klas_cli/src/errors/cli_errors.dart';
import 'package:klasflow/klasflow.dart';
import 'package:test/test.dart';

void main() {
  test('maps invalid credentials to stable auth error', () {
    final error = ErrorMapper().map(
      const InvalidCredentialsException(
        'upstream rejected login for student-id=20240001',
      ),
    );

    expect(error.code, 'AUTH_INVALID_CREDENTIALS');
    expect(error.exitCode, ExitCodes.auth);
    expect(
      error.message,
      'Authentication failed. The provided credentials were rejected.',
    );
    expect(error.hint, contains('KLAS_ID'));
    expect(error.message, isNot(contains('20240001')));
    expect(error.message, isNot(contains('upstream rejected login')));
    expect(error.hint, isNot(contains('20240001')));
    expect(error.hint, isNot(contains('upstream rejected login')));
  });

  test('maps session expiry to stable auth expired error', () {
    final error = ErrorMapper().map(
      const SessionExpiredException(
        'session refresh failed for sid=expired-session-raw',
      ),
    );

    expect(error.code, 'AUTH_EXPIRED');
    expect(error.exitCode, ExitCodes.auth);
    expect(error.message, 'The KLAS session expired and could not be reused.');
    expect(error.hint, contains('klas auth login'));
    expect(error.message, isNot(contains('expired-session-raw')));
    expect(error.message, isNot(contains('session refresh failed')));
    expect(error.hint, isNot(contains('expired-session-raw')));
    expect(error.hint, isNot(contains('session refresh failed')));
  });

  test('maps captcha challenges to stable auth required error', () {
    final error = ErrorMapper().map(
      const CaptchaRequiredException('captcha image token=captcha-raw-token'),
    );

    expect(error.code, 'AUTH_REQUIRED');
    expect(error.exitCode, ExitCodes.auth);
    expect(
      error.message,
      'Interactive login is required because KLAS requested a captcha challenge.',
    );
    expect(error.hint, 'Run `klas auth login` in a terminal session.');
    expect(error.message, isNot(contains('captcha-raw-token')));
    expect(error.message, isNot(contains('captcha image token')));
    expect(error.hint, isNot(contains('captcha-raw-token')));
    expect(error.hint, isNot(contains('captcha image token')));
  });

  test('maps network failures to sanitized network error', () {
    final error = ErrorMapper().map(
      const NetworkException(
        'socket reset while fetching host=portal.klas.example secret=raw-network',
      ),
    );

    expect(error.code, 'NETWORK_ERROR');
    expect(
      error.message,
      'A network or KLAS service error occurred while processing the request.',
    );
    expect(
      error.hint,
      'Try again in a moment. If the problem persists, check network access to KLAS.',
    );
    expect(error.message, isNot(contains('portal.klas.example')));
    expect(error.message, isNot(contains('raw-network')));
    expect(error.hint, isNot(contains('portal.klas.example')));
    expect(error.hint, isNot(contains('raw-network')));
  });

  test('maps unexpected failures to sanitized internal error', () {
    final error = ErrorMapper().map(
      Exception('raw upstream body secret=internal-stacktrace'),
    );

    expect(error.code, 'INTERNAL_ERROR');
    expect(
      error.message,
      'An unexpected internal error occurred while processing the command.',
    );
    expect(
      error.hint,
      'Run the command again. If the problem persists, inspect the environment or update the CLI.',
    );
    expect(error.message, isNot(contains('raw upstream body')));
    expect(error.message, isNot(contains('internal-stacktrace')));
    expect(error.hint, isNot(contains('raw upstream body')));
    expect(error.hint, isNot(contains('internal-stacktrace')));
  });
}
