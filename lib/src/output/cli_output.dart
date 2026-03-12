import '../auth/terminal.dart';
import '../errors/cli_errors.dart';
import '../models/cli_models.dart';
import '../validation/input_validation.dart';

final class CliOutput {
  const CliOutput({
    required this.terminal,
    required this.format,
    this.selectedFields = const <String>[],
  });

  final Terminal terminal;
  final OutputFormat format;
  final List<String> selectedFields;

  void printSuccess<T>(
    String command,
    CommandPayload<T> payload, {
    required Object? Function(T value) toJson,
    required String Function(T value) toText,
  }) {
    if (format == OutputFormat.json) {
      final meta = <String, Object?>{
        ...payload.meta,
        if (selectedFields.isNotEmpty) 'fields': selectedFields,
      };
      terminal.writeOut(
        prettyJson(<String, Object?>{
          'ok': true,
          'schema_version': '1.0',
          'command': command,
          'data': selectJsonFields(toJson(payload.data), selectedFields),
          'meta': meta,
          'warnings': payload.warnings,
        }),
      );
      return;
    }

    terminal.writeOut(toText(payload.data));
    for (final warning in payload.warnings) {
      terminal.writeErr('Warning: $warning');
    }
  }

  void printError(String command, CliException error) {
    if (format == OutputFormat.json) {
      terminal.writeOut(
        prettyJson(<String, Object?>{
          'ok': false,
          'schema_version': '1.0',
          'command': command,
          'data': null,
          'error': <String, Object?>{
            'code': error.code,
            'message': error.message,
            'retryable': error.retryable,
            'hint': error.hint,
            'details': error.details,
          },
          'meta': const <String, Object?>{},
          'warnings': const <String>[],
        }),
      );
      return;
    }

    terminal.writeErr(error.message);
    if (error.hint != null && error.hint!.trim().isNotEmpty) {
      terminal.writeErr('Hint: ${error.hint}');
    }
  }
}
