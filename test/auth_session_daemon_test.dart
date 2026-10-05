import 'dart:convert';
import 'dart:io';

import 'package:klas_cli/src/auth/credential_store.dart';
import 'package:klas_cli/src/auth/session_manager.dart';
import 'package:klas_cli/src/auth/session_metadata.dart';
import 'package:test/test.dart';

void main() {
  test(
    'real auth daemon starts, protects credentials, and cleans up on logout',
    () async {
      final temp = await Directory.systemTemp.createTemp('klas_authd_test_');
      final metadataFile = File('${temp.path}/auth-session.json');
      Process? process;
      late Future<String> output;
      late Future<String> errors;
      final store = _MemoryCredentials();
      final manager = LocalAuthSessionManager(
        stateDirectory: temp,
        credentialStore: store,
        daemonLauncher: (path) async {
          final child = await Process.start(Platform.resolvedExecutable, [
            File('bin/klas.dart').absolute.path,
            '__authd',
            '--metadata-file',
            path,
          ]);
          process = child;
          output = utf8.decodeStream(child.stdout);
          errors = utf8.decodeStream(child.stderr);
          return child;
        },
      );
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        await manager.save(
          const SessionCredentials(
            id: 'synthetic-user',
            password: 'synthetic-password',
          ),
        );
        expect(await manager.hasSession(), isTrue);
        expect((await manager.load())?.id, 'synthetic-user');
        final metadata = jsonDecode(await metadataFile.readAsString()) as Map;
        final port = metadata['port'];
        final token = metadata['token'];
        Future<HttpClientResponse> request(
          String method,
          String path, {
          bool authorized = true,
        }) async {
          final req = await client.openUrl(
            method,
            Uri.parse('http://127.0.0.1:$port$path'),
          );
          if (authorized) {
            req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
          }
          return req.close().timeout(const Duration(seconds: 5));
        }

        final denied = await request(
          'GET',
          '/v1/credentials',
          authorized: false,
        );
        expect(denied.statusCode, HttpStatus.unauthorized);
        expect(await utf8.decodeStream(denied), isEmpty);
        final status = await request('GET', '/v1/status');
        expect(status.statusCode, HttpStatus.ok);
        expect(
          status.headers.value(HttpHeaders.cacheControlHeader),
          'no-store',
        );
        expect(
          jsonDecode(await utf8.decodeStream(status))['authenticated'],
          isTrue,
        );
        final credentials = await request('GET', '/v1/credentials');
        expect(jsonDecode(await utf8.decodeStream(credentials)), {
          'id': 'synthetic-user',
          'password': 'synthetic-password',
        });
        await manager.clear();
        expect(await process!.exitCode.timeout(const Duration(seconds: 5)), 0);
        expect(await manager.hasSession(), isFalse);
        expect(await metadataFile.exists(), isFalse);
        expect(await output, isEmpty);
        expect(await errors, isEmpty);
      } finally {
        client.close(force: true);
        process?.kill();
        final resolved = await temp.resolveSymbolicLinks();
        expect(resolved.toLowerCase(), temp.absolute.path.toLowerCase());
        await temp.delete(recursive: true);
      }
    },
  );
}

final class _MemoryCredentials implements CredentialStore {
  SessionCredentials? _credentials;
  @override
  String get backendLabel => 'test-memory';
  @override
  Future<void> save(SessionCredentials credentials) async {
    _credentials = credentials;
  }

  @override
  Future<SessionCredentials?> load() async => _credentials;
  @override
  Future<bool> hasCredentials() async => _credentials != null;
  @override
  Future<void> clear() async {
    _credentials = null;
  }
}
