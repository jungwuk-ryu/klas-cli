import 'dart:async';
import 'dart:io';

abstract interface class Terminal {
  bool get canPrompt;

  void writeOut(String message);

  void writeErr(String message);

  Future<String?> prompt(String message, {bool secret = false});
}

final class IoTerminal implements Terminal {
  @override
  bool get canPrompt => stdin.hasTerminal && stderr.hasTerminal;

  @override
  Future<String?> prompt(String message, {bool secret = false}) async {
    stderr.write(message);
    if (!secret) {
      return stdin.readLineSync();
    }

    final previousEchoMode = stdin.echoMode;
    final previousLineMode = stdin.lineMode;
    try {
      stdin.echoMode = false;
      stdin.lineMode = true;
      final value = stdin.readLineSync();
      stderr.writeln();
      return value;
    } finally {
      stdin.echoMode = previousEchoMode;
      stdin.lineMode = previousLineMode;
    }
  }

  @override
  void writeErr(String message) {
    stderr.writeln(message);
  }

  @override
  void writeOut(String message) {
    stdout.writeln(message);
  }
}
