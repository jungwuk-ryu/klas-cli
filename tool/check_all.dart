import 'dart:io';

final class _Step {
  const _Step(this.name, this.command);

  final String name;
  final List<String> command;
}

Future<void> main() async {
  final steps = <_Step>[
    const _Step('Install dependencies', ['dart', 'pub', 'get']),
    const _Step('Static analysis', ['dart', 'analyze']),
    const _Step('Unit tests', ['dart', 'test']),
    const _Step('Schema smoke check', [
      'dart',
      'run',
      'bin/klas.dart',
      '--format',
      'json',
      'schema',
      'tasks',
      'list',
    ]),
    const _Step('Dry-run smoke check', [
      'dart',
      'run',
      'bin/klas.dart',
      '--format',
      'json',
      '--dry-run',
      'tasks',
      'show',
      '12',
      '--course',
      'CSE101',
    ]),
  ];

  for (final step in steps) {
    stdout.writeln('==> ${step.name}');
    final exitCode = await _run(step.command);
    if (exitCode != 0) {
      stderr.writeln('Step failed: ${step.name}');
      exit(exitCode);
    }
  }

  stdout.writeln('All checks passed.');
}

Future<int> _run(List<String> command) async {
  final process = await Process.start(
    command.first,
    command.skip(1).toList(growable: false),
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  return process.exitCode;
}
