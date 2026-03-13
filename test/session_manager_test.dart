import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:klas_cli/src/auth/credential_store.dart';
import 'package:klas_cli/src/auth/session_manager.dart';
import 'package:klas_cli/src/auth/session_metadata.dart';
import 'package:klas_cli/src/errors/cli_errors.dart';
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
        credentialStore: PersistentCredentialStore(
          stateDirectory: tempDir,
          keyStores: <MasterKeyStore>[
            FileMasterKeyStore(stateDirectory: tempDir),
          ],
        ),
        daemonLauncher: _fakeDaemonLauncher(
          const SessionCredentials(id: 'agent-user', password: 'agent-pass'),
        ),
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
    timeout: const Timeout(Duration(minutes: 5)),
    skip: 'Nested daemon integration is covered by manual CLI QA.',
  );

  test(
    'local auth session manager recreates daemon from durable credentials',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'klas-cli-session-restore-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final manager = LocalAuthSessionManager(
        stateDirectory: tempDir,
        credentialStore: PersistentCredentialStore(
          stateDirectory: tempDir,
          keyStores: <MasterKeyStore>[
            FileMasterKeyStore(stateDirectory: tempDir),
          ],
        ),
        daemonLauncher: _fakeDaemonLauncher(
          const SessionCredentials(
            id: 'restore-user',
            password: 'restore-pass',
          ),
        ),
      );

      await manager.save(
        const SessionCredentials(id: 'restore-user', password: 'restore-pass'),
      );
      await File('${tempDir.path}/auth-session.json').delete();

      expect(await manager.hasSession(), isTrue);
      final credentials = await manager.load();

      expect(credentials, isNotNull);
      expect(credentials!.id, 'restore-user');
      expect(credentials.password, 'restore-pass');
      expect(await File('${tempDir.path}/auth-session.json').exists(), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: 'Nested daemon integration is covered by manual CLI QA.',
  );

  test('failed daemon startup rolls back durable credentials', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'klas-cli-session-failure-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = PersistentCredentialStore(
      stateDirectory: tempDir,
      keyStores: <MasterKeyStore>[FileMasterKeyStore(stateDirectory: tempDir)],
    );
    final manager = LocalAuthSessionManager(
      stateDirectory: tempDir,
      credentialStore: store,
      daemonLauncher: (_) => Process.start('/bin/sh', <String>[
        '-c',
        'exit 1',
      ], mode: ProcessStartMode.detachedWithStdio),
    );

    await expectLater(
      manager.save(
        const SessionCredentials(id: 'bad-user', password: 'bad-pass'),
      ),
      throwsA(isA<CliException>()),
    );

    expect(await store.hasCredentials(), isFalse);
  });
}

SessionDaemonLauncher _fakeDaemonLauncher(SessionCredentials credentials) {
  return (metadataFilePath) async {
    final metadataFile = File(metadataFilePath);
    final token = 'test-token';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final metadata = AuthSessionMetadata(
      schemaVersion: '1.0',
      port: server.port,
      token: token,
      pid: pid,
      createdAt: DateTime.now().toIso8601String(),
    );

    await metadataFile.parent.create(recursive: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['700', metadataFile.parent.path]);
    }
    await metadataFile.writeAsString(metadata.encode());
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['600', metadataFile.path]);
    }

    unawaited(() async {
      await for (final request in server) {
        if (request.headers.value(HttpHeaders.authorizationHeader) !=
            'Bearer $token') {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          continue;
        }

        switch ('${request.method} ${request.uri.path}') {
          case 'GET /v1/status':
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode(<String, Object?>{'ok': true}));
            await request.response.close();
            break;
          case 'GET /v1/credentials':
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode(credentials.toJson()));
            await request.response.close();
            break;
          case 'POST /v1/logout':
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode(<String, Object?>{'ok': true}));
            await request.response.close();
            await server.close(force: true);
            if (await metadataFile.exists()) {
              await metadataFile.delete();
            }
            break;
          default:
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            break;
        }
      }
    }());

    return Process.start('/bin/sh', <String>[
      '-c',
      'cat >/dev/null; sleep 60',
    ], mode: ProcessStartMode.detachedWithStdio);
  };
}
