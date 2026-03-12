import 'dart:io';

import 'package:klas_cli/klas_cli.dart';

Future<void> main(List<String> arguments) async {
  final exitCode = await runKlasCli(arguments);
  if (exitCode != 0) {
    stderr.flush();
  }
  exit(exitCode);
}
