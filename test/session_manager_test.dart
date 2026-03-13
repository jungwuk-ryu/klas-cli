import 'dart:io';

import 'package:klas_cli/src/auth/session_manager.dart';
import 'package:klas_cli/src/auth/session_metadata.dart';
import 'package:test/test.dart';

void main() {
  test(
    'local auth session manager persists daemon-backed reusable session lifecycle',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'klas-cli-session-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final manager = LocalAuthSessionManager(
        stateDirectory: tempDir,
        daemonLauncher: (metadataFilePath) {
          return Process.start(
            Platform.resolvedExecutable,
            <String>[
              'run',
              'bin/klas.dart',
              '__authd',
              '--metadata-file',
              metadataFilePath,
            ],
            workingDirectory: Directory.current.path,
            mode: ProcessStartMode.detachedWithStdio,
          );
        },
      );

      await manager.save(
        const SessionCredentials(id: 'agent-user', password: 'agent-pass'),
      );

      if (!Platform.isWindows) {
        final directoryMode = await Process.run('stat', <String>[
          '-c',
          '%a',
          tempDir.path,
        ]);
        final fileMode = await Process.run('stat', <String>[
          '-c',
          '%a',
          '${tempDir.path}/auth-session.json',
        ]);
        expect(directoryMode.exitCode, 0);
        expect(fileMode.exitCode, 0);
        expect((directoryMode.stdout as String).trim(), '700');
        expect((fileMode.stdout as String).trim(), '600');
      }

      expect(await manager.hasSession(), isTrue);
      final credentials = await manager.load();
      expect(credentials, isNotNull);
      expect(credentials!.id, 'agent-user');
      expect(credentials.password, 'agent-pass');

      await manager.clear();

      expect(await manager.hasSession(), isFalse);
      expect(await manager.load(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
