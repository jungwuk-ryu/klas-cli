import 'package:klas_cli/src/errors/cli_errors.dart';
import 'package:klasflow/klasflow.dart';
import 'package:test/test.dart';

void main() {
  test('maps invalid credentials to stable auth error', () {
    final error = ErrorMapper().map(
      const InvalidCredentialsException('invalid credentials'),
    );

    expect(error.code, 'AUTH_INVALID_CREDENTIALS');
    expect(error.exitCode, ExitCodes.auth);
    expect(error.hint, contains('KLAS_ID'));
  });

  test('maps session expiry to stable auth expired error', () {
    final error = ErrorMapper().map(
      const SessionExpiredException('expired'),
    );

    expect(error.code, 'AUTH_EXPIRED');
    expect(error.exitCode, ExitCodes.auth);
  });

  test('maps network failures to sanitized network error', () {
    final error = ErrorMapper().map(
      const NetworkException('upstream payload with secrets'),
    );

    expect(error.code, 'NETWORK_ERROR');
    expect(error.message, 'A network or KLAS service error occurred while processing the request.');
    expect(error.message, isNot(contains('secrets')));
  });

  test('maps unexpected failures to sanitized internal error', () {
    final error = ErrorMapper().map(Exception('raw upstream body'));

    expect(error.code, 'INTERNAL_ERROR');
    expect(error.message, 'An unexpected internal error occurred while processing the command.');
    expect(error.message, isNot(contains('raw upstream body')));
  });
}
