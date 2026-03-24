import 'dart:io';

final class _Step {
  const _Step(this.name, this.command);

  final String name;
  final List<String> command;
}

final class _StepResult {
  const _StepResult({required this.exitCode, required this.warningOnly});

  final int exitCode;
  final bool warningOnly;
}

Future<void> main() async {
  final steps = <_Step>[
    const _Step('Install dependencies', ['dart', 'pub', 'get']),
    const _Step('Static analysis', ['dart', 'analyze']),
    const _Step('Unit tests', ['dart', 'test']),
    const _Step('Root schema smoke check', [
      'dart',
      'run',
      'bin/klas.dart',
      '--format',
      'json',
      'schema',
    ]),
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
    const _Step('Installer contract tests', [
      'dart',
      'test',
      'test/installers/install_contract_test.dart',
    ]),
    const _Step('Publish dry-run', ['dart', 'pub', 'publish', '--dry-run']),
  ];

  for (final step in steps) {
    stdout.writeln('==> ${step.name}');
    final result = await _run(
      step.command,
      cleanSnapshotIfPublishDryRun: step.name == 'Publish dry-run',
    );
    if (result.exitCode != 0 && !result.warningOnly) {
      stderr.writeln('Step failed: ${step.name}');
      exit(result.exitCode);
    }
  }

  stdout.writeln('All checks passed.');
}

String _basenameFromPath(String path) {
  var p = path;
  while (p.endsWith(Platform.pathSeparator)) {
    p = p.substring(0, p.length - Platform.pathSeparator.length);
  }
  final parts = p.split(Platform.pathSeparator);
  return parts.isEmpty ? '' : parts.last;
}

Future<_StepResult> _run(
  List<String> command, {
  required bool cleanSnapshotIfPublishDryRun,
}) async {
  String? workingDirectory;
  if (cleanSnapshotIfPublishDryRun) {
    try {
      workingDirectory = await _createPublishSnapshotDirectory();
      // Ensure the snapshot has a resolved package config so that the
      // publish-time `dart analyze` (run by pub) can resolve imports.
      final bootstrap = await _runInWorkingDirectory([
        'dart',
        'pub',
        'get',
      ], workingDirectory);
      if (bootstrap.exitCode != 0) {
        return bootstrap;
      }
    } on Object catch (e) {
      stderr.writeln('Publish snapshot error: $e');
      return const _StepResult(exitCode: 1, warningOnly: false);
    }
  }

  try {
    return await _runInWorkingDirectory(command, workingDirectory);
  } finally {
    if (workingDirectory != null) {
      await _deleteDirectoryIfExists(Directory(workingDirectory));
    }
  }
}

Future<_StepResult> _runInWorkingDirectory(
  List<String> command,
  String? workingDirectory,
) async {
  final process = await Process.start(
    command.first,
    command.skip(1).toList(growable: false),
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
    workingDirectory: workingDirectory,
  );
  final exitCode = await process.exitCode;
  return _StepResult(exitCode: exitCode, warningOnly: false);
}

Future<String> _createPublishSnapshotDirectory() async {
  final sourceRoot = Directory.current.absolute;
  final tempRoot = await Directory.systemTemp.createTemp('klas_cli_publish_');
  final snapshotRoot = Directory('${tempRoot.path}/snapshot');
  await snapshotRoot.create(recursive: true);

  const excludeTopLevelNames = <String>{
    '.git',
    '.dart_tool',
    '.sisyphus',
    'build',
  };

  await for (final entity in sourceRoot.list(followLinks: false)) {
    final name = _basenameFromPath(entity.path);
    if (name.isEmpty) {
      continue;
    }
    if (excludeTopLevelNames.contains(name)) {
      continue;
    }

    // Avoid copying CI/temp artifacts that can confuse publish validation.
    if (name.startsWith('.git') || name.startsWith('task-')) {
      continue;
    }

    final targetPath = '${snapshotRoot.path}/$name';
    if (entity is File) {
      await entity.copy(targetPath);
      continue;
    }
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
      continue;
    }
    if (entity is Link) {
      // Keep snapshot deterministic and portable; skip symlinks.
      continue;
    }
  }

  // Deterministic safety: ensure `bin/klas.dart` exists in the snapshot even if
  // the directory walk behaved unexpectedly (e.g. odd temp artifacts).
  await _ensureFileCopied(
    sourcePath: '${sourceRoot.path}/bin/klas.dart',
    targetPath: '${snapshotRoot.path}/bin/klas.dart',
  );

  // Pub checks `executables:` against `bin/<script>.dart`.
  await _ensurePublishExecutableContract(snapshotRoot.path);

  return snapshotRoot.path;
}

Future<void> _ensureFileCopied({
  required String sourcePath,
  required String targetPath,
}) async {
  final source = File(sourcePath);
  if (!await source.exists()) {
    return;
  }
  final target = File(targetPath);
  if (await target.exists()) {
    return;
  }
  await target.parent.create(recursive: true);
  await source.copy(target.path);
}

Future<void> _ensurePublishExecutableContract(String snapshotRootPath) async {
  final pubspec = File('$snapshotRootPath/pubspec.yaml');
  if (!await pubspec.exists()) {
    return;
  }

  final contents = await pubspec.readAsString();
  if (!contents.contains(RegExp(r'^\s*executables\s*:\s*$', multiLine: true))) {
    return;
  }

  // Specifically handle this package's `klas: klas` entry.
  if (!contents.contains(
    RegExp(r'^\s{2}klas\s*:\s*klas\s*$', multiLine: true),
  )) {
    return;
  }

  final binDir = Directory('$snapshotRootPath/bin');
  final source = File('${binDir.path}/klas.dart');
  if (!await source.exists()) {
    throw StateError('Publish snapshot missing required bin/klas.dart');
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final name = _basenameFromPath(entity.path);
    if (name.isEmpty) {
      continue;
    }
    final targetPath = '${target.path}/$name';
    if (entity is File) {
      await entity.copy(targetPath);
      continue;
    }
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
      continue;
    }
    // Skip links and other special files.
  }
}

Future<void> _deleteDirectoryIfExists(Directory dir) async {
  if (await dir.exists()) {
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Best-effort cleanup.
    }
  }
}
