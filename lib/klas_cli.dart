import 'dart:async';

import 'src/commands/klas_command_runner.dart';
import 'src/auth/session_manager.dart';
import 'src/errors/cli_errors.dart';
import 'src/models/cli_models.dart';
import 'src/output/cli_output.dart';
import 'src/services/klas_service.dart';
import 'src/auth/terminal.dart';

Future<int> runKlasCli(
  List<String> arguments, {
  Terminal? terminal,
  KlasService? service,
}) async {
  final resolvedTerminal = terminal ?? IoTerminal();
  final resolvedFormat = detectOutputFormat(arguments);
  final output = CliOutput(terminal: resolvedTerminal, format: resolvedFormat);
  final sessionManager = LocalAuthSessionManager();
  final resolvedService =
      service ?? KlasflowService(terminal: resolvedTerminal, sessionManager: sessionManager);
  final runner = KlasCommandRunner(
    terminal: resolvedTerminal,
    service: resolvedService,
    sessionManager: sessionManager,
  );

  try {
    final result = await runner.run(arguments);
    return result ?? ExitCodes.success;
  } on CliException catch (error) {
    output.printError(runner.describeCommand(arguments), error);
    return error.exitCode;
  } catch (error) {
    final mapped = ErrorMapper().map(error);
    output.printError(runner.describeCommand(arguments), mapped);
    return mapped.exitCode;
  }
}
