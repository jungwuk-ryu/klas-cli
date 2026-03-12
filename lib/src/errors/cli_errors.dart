import 'package:args/command_runner.dart';
import 'package:klasflow/klasflow.dart';

import '../models/cli_models.dart';

final class ExitCodes {
  static const success = 0;
  static const usage = 64;
  static const auth = 65;
  static const notFound = 66;
  static const network = 69;
  static const software = 70;
}

final class CliException implements Exception {
  const CliException({
    required this.code,
    required this.message,
    required this.exitCode,
    this.retryable = false,
    this.hint,
    this.details = const <String, Object?>{},
  });

  final String code;
  final String message;
  final int exitCode;
  final bool retryable;
  final String? hint;
  final JsonMap details;
}

final class ErrorMapper {
  CliException map(Object error) {
    if (error is CliException) {
      return error;
    }
    if (error is UsageException || error is FormatException) {
      return CliException(
        code: 'USAGE_ERROR',
        message: '$error',
        exitCode: ExitCodes.usage,
        hint: 'Run the command again with --help to see valid usage.',
      );
    }
    if (error is InvalidCredentialsException) {
      return const CliException(
        code: 'AUTH_INVALID_CREDENTIALS',
        message: 'Authentication failed. The provided credentials were rejected.',
        exitCode: ExitCodes.auth,
        hint: 'Check KLAS_ID/KLAS_PASSWORD or run `klas auth login` interactively.',
      );
    }
    if (error is SessionExpiredException) {
      return const CliException(
        code: 'AUTH_EXPIRED',
        message: 'The KLAS session expired and could not be reused.',
        exitCode: ExitCodes.auth,
        hint: 'Set KLAS_ID/KLAS_PASSWORD for automatic re-login or run `klas auth login`.',
      );
    }
    if (error is CaptchaRequiredException) {
      return const CliException(
        code: 'AUTH_REQUIRED',
        message: 'Interactive login is required because KLAS requested a captcha challenge.',
        exitCode: ExitCodes.auth,
        hint: 'Run `klas auth login` in a terminal session.',
      );
    }
    if (error is OtpRequiredException) {
      return const CliException(
        code: 'AUTH_REQUIRED',
        message: 'Interactive login is required because KLAS requested an OTP challenge.',
        exitCode: ExitCodes.auth,
        hint: 'Run `klas auth login` in a terminal session.',
      );
    }
    if (error is NetworkException || error is ServiceUnavailableException) {
      return const CliException(
        code: 'NETWORK_ERROR',
        message: 'A network or KLAS service error occurred while processing the request.',
        exitCode: ExitCodes.network,
        retryable: true,
        hint: 'Try again in a moment. If the problem persists, check network access to KLAS.',
      );
    }
    if (error is ParsingException) {
      return const CliException(
        code: 'INTERNAL_ERROR',
        message: 'The KLAS response could not be interpreted safely.',
        exitCode: ExitCodes.software,
        hint: 'The upstream response shape changed or was incomplete.',
      );
    }
    return const CliException(
      code: 'INTERNAL_ERROR',
      message: 'An unexpected internal error occurred while processing the command.',
      exitCode: ExitCodes.software,
      hint: 'Run the command again. If the problem persists, inspect the environment or update the CLI.',
    );
  }
}
