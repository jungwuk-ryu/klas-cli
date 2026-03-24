import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:klas_cli/src/auth/credential_store.dart';
import 'package:klas_cli/src/auth/session_manager.dart';
import 'package:klas_cli/src/auth/session_metadata.dart';
import 'package:klas_cli/src/errors/cli_errors.dart';
import 'package:test/test.dart';

final Map<String, Future<void> Function()> _fakeDaemonClosersByMetadataPath =
    <String, Future<void> Function()>{};

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
        await _expectOwnerOnlyUnixPermissions(tempDir.path, isDirectory: true);
        await _expectOwnerOnlyUnixPermissions(
          '${tempDir.path}/auth-session.json',
          isDirectory: false,
        );
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
      final metadataFilePath = '${tempDir.path}/auth-session.json';
      await _closeFakeDaemon(metadataFilePath);
      expect(await File(metadataFilePath).exists(), isFalse);

      expect(await manager.hasSession(), isTrue);
      final credentials = await manager.load();

      expect(credentials, isNotNull);
      expect(credentials!.id, 'restore-user');
      expect(credentials.password, 'restore-pass');
      expect(await File(metadataFilePath).exists(), isTrue);

      await manager.clear();
    },
    timeout: const Timeout(Duration(minutes: 5)),
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
      daemonLauncher: (_) async => throw const CliException(
        code: 'INTERNAL_ERROR',
        message: 'Failed to start reusable auth session.',
        exitCode: ExitCodes.software,
      ),
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
    final process = _FakeDaemonProcess();
    final metadataFile = File(metadataFilePath);
    HttpServer? server;
    var closed = false;

    Future<bool> abortBootstrapIfClosed() async {
      if (!closed) {
        return false;
      }
      final currentServer = server;
      server = null;
      if (currentServer != null) {
        unawaited(currentServer.close(force: true));
      }
      return true;
    }

    Future<void> closeDaemon({bool deleteMetadata = true}) async {
      if (closed) {
        return;
      }
      closed = true;
      final currentServer = server;
      server = null;
      if (currentServer != null) {
        unawaited(currentServer.close(force: true));
      }
      if (deleteMetadata) {
        try {
          if (await metadataFile.exists()) {
            await metadataFile.delete();
          }
        } on PathNotFoundException {
          // logout may remove the metadata file before teardown does
        }
      }
      if (identical(
        _fakeDaemonClosersByMetadataPath[metadataFilePath],
        closeDaemon,
      )) {
        _fakeDaemonClosersByMetadataPath.remove(metadataFilePath);
      }
      await process.complete();
    }

    addTearDown(closeDaemon);
    _fakeDaemonClosersByMetadataPath[metadataFilePath] = closeDaemon;

    unawaited(() async {
      try {
        final payload = await process.readStdin();
        if (await abortBootstrapIfClosed()) {
          return;
        }
        final decoded = SessionCredentials.fromJson(
          (jsonDecode(payload) as Map<String, dynamic>).cast<String, Object?>(),
        );
        if (decoded.id != credentials.id ||
            decoded.password != credentials.password) {
          throw StateError('Fake daemon received unexpected credentials.');
        }

        const token = 'test-token-for-session-manager-lifecycle-123';
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        if (await abortBootstrapIfClosed()) {
          return;
        }
        final metadata = AuthSessionMetadata(
          schemaVersion: '1.0',
          port: server!.port,
          token: token,
          pid: process.pid,
          createdAt: DateTime.now().toIso8601String(),
        );

        await metadataFile.parent.create(recursive: true);
        if (!Platform.isWindows) {
          await Process.run('chmod', <String>['700', metadataFile.parent.path]);
        }
        final tempFile = File('${metadataFile.path}.tmp.${process.pid}');
        await tempFile.writeAsString(metadata.encode());
        if (!Platform.isWindows) {
          await Process.run('chmod', <String>['600', tempFile.path]);
        }
        await tempFile.rename(metadataFile.path);
        if (!Platform.isWindows) {
          await Process.run('chmod', <String>['600', metadataFile.path]);
        }
        if (await abortBootstrapIfClosed()) {
          return;
        }

        server!.listen((request) {
          unawaited(() async {
            if (request.headers.value(HttpHeaders.authorizationHeader) !=
                'Bearer $token') {
              request.response.statusCode = HttpStatus.unauthorized;
              await request.response.close();
              return;
            }

            switch ('${request.method} ${request.uri.path}') {
              case 'GET /v1/status':
                request.response.headers.contentType = ContentType.json;
                request.response.write(
                  jsonEncode(<String, Object?>{'ok': true}),
                );
                await request.response.close();
                break;
              case 'GET /v1/credentials':
                request.response.headers.contentType = ContentType.json;
                request.response.write(jsonEncode(credentials.toJson()));
                await request.response.close();
                break;
              case 'POST /v1/logout':
                request.response.headers.contentType = ContentType.json;
                request.response.write(
                  jsonEncode(<String, Object?>{'ok': true}),
                );
                await request.response.close();
                unawaited(closeDaemon(deleteMetadata: false));
                break;
              default:
                request.response.statusCode = HttpStatus.notFound;
                await request.response.close();
                break;
            }
          }());
        });
      } catch (error) {
        await process.fail(error.toString());
        await closeDaemon();
      }
    }());

    return process;
  };
}

Future<void> _closeFakeDaemon(String metadataFilePath) async {
  final closeDaemon = _fakeDaemonClosersByMetadataPath[metadataFilePath];
  if (closeDaemon != null) {
    await closeDaemon();
  }
}

Future<void> _expectOwnerOnlyUnixPermissions(
  String path, {
  required bool isDirectory,
}) async {
  final mode = (await FileStat.stat(path)).modeString();
  final pattern = isDirectory
      ? RegExp(r'^[a-z-]?rwx------$')
      : RegExp(r'^[a-z-]?rw-------$');
  expect(
    mode,
    matches(pattern),
    reason:
        'Expected ${isDirectory ? 'directory' : 'file'} permissions to be owner-only, got $mode for $path.',
  );
}

final class _FakeDaemonProcess implements Process {
  _FakeDaemonProcess()
    : _stdinController = StreamController<List<int>>(),
      _stdoutController = StreamController<List<int>>(),
      _stderrController = StreamController<List<int>>(),
      pid = DateTime.now().microsecondsSinceEpoch {
    stdin = IOSink(_stdinController.sink);
  }

  final StreamController<List<int>> _stdinController;
  final StreamController<List<int>> _stdoutController;
  final StreamController<List<int>> _stderrController;

  @override
  late final IOSink stdin;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  final int pid;

  final Completer<int> _exitCode = Completer<int>();
  var _closed = false;

  @override
  Future<int> get exitCode => _exitCode.future;

  Future<String> readStdin() async {
    final payload = await utf8.decoder.bind(_stdinController.stream).join();
    return payload.trim();
  }

  Future<void> fail(String message) async {
    if (_closed) {
      return;
    }
    _stderrController.add(utf8.encode('$message\n'));
    await _finish(1);
  }

  Future<void> complete() => _finish(0);

  Future<void> _finish(int code) {
    if (_closed) {
      return Future<void>.value();
    }
    _closed = true;

    final stdinClose = stdin.close();
    final stdoutClose = _stdoutController.close();
    final stderrClose = _stderrController.close();

    if (!_exitCode.isCompleted) {
      _exitCode.complete(code);
    }

    unawaited(stdinClose);
    unawaited(stdoutClose);
    unawaited(stderrClose);

    return Future<void>.value();
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    unawaited(_finish(0));
    return true;
  }
}
