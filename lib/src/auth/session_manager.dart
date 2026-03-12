import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../errors/cli_errors.dart';
import '../models/cli_models.dart';
import 'session_metadata.dart';

abstract interface class AuthSessionManager {
  Future<void> save(SessionCredentials credentials);

  Future<SessionCredentials?> load();

  Future<bool> hasSession();

  Future<void> clear();
}

typedef SessionDaemonLauncher = Future<Process> Function(String metadataFilePath);

final class LocalAuthSessionManager implements AuthSessionManager {
  LocalAuthSessionManager({
    Directory? stateDirectory,
    SessionDaemonLauncher? daemonLauncher,
  })
    : _stateDirectory =
          stateDirectory ?? _defaultStateDirectory(),
      _daemonLauncher = daemonLauncher ?? _defaultDaemonLauncher;

  final Directory _stateDirectory;
  final SessionDaemonLauncher _daemonLauncher;

  File get _metadataFile => File('${_stateDirectory.path}/auth-session.json');

  @override
  Future<void> save(SessionCredentials credentials) async {
    await clear();
    await _stateDirectory.create(recursive: true);
    final process = await _daemonLauncher(_metadataFile.path);

    process.stdin.writeln(jsonEncode(credentials.toJson()));
    await process.stdin.close();

    final ready = await _waitForMetadata();
    if (ready == null) {
      final error = await utf8.decodeStream(process.stderr);
      throw CliException(
        code: 'INTERNAL_ERROR',
        message: 'Failed to start reusable auth session.',
        exitCode: ExitCodes.software,
        hint: error.trim().isEmpty ? null : error.trim(),
      );
    }
  }

  @override
  Future<SessionCredentials?> load() async {
    final metadata = await _readMetadata();
    if (metadata == null) {
      return null;
    }
    try {
      final payload = await _request(
        metadata,
        method: 'GET',
        path: '/v1/credentials',
      );
      return SessionCredentials.fromJson(payload);
    } catch (_) {
      await _cleanupStaleSession();
      return null;
    }
  }

  @override
  Future<bool> hasSession() async {
    final metadata = await _readMetadata();
    if (metadata == null) {
      return false;
    }
    try {
      await _request(metadata, method: 'GET', path: '/v1/status');
      return true;
    } catch (_) {
      await _cleanupStaleSession();
      return false;
    }
  }

  @override
  Future<void> clear() async {
    final metadata = await _readMetadata();
    if (metadata != null) {
      try {
        await _request(metadata, method: 'POST', path: '/v1/logout');
      } catch (_) {
        // stale daemon cleanup continues below
      }
    }
    await _cleanupStaleSession();
  }

  Future<AuthSessionMetadata?> _waitForMetadata() async {
    for (var attempt = 0; attempt < 50; attempt++) {
      final metadata = await _readMetadata();
      if (metadata != null) {
        try {
          await _request(metadata, method: 'GET', path: '/v1/status');
          return metadata;
        } catch (_) {
          // wait a bit more
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<AuthSessionMetadata?> _readMetadata() async {
    if (!await _metadataFile.exists()) {
      return null;
    }
    try {
      return AuthSessionMetadata.decode(await _metadataFile.readAsString());
    } catch (_) {
      await _cleanupStaleSession();
      return null;
    }
  }

  Future<void> _cleanupStaleSession() async {
    if (await _metadataFile.exists()) {
      await _metadataFile.delete();
    }
  }

  Future<JsonMap> _request(
    AuthSessionMetadata metadata, {
    required String method,
    required String path,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:${metadata.port}$path'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${metadata.token}');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode != HttpStatus.ok) {
        throw const CliException(
          code: 'AUTH_REQUIRED',
          message: 'Reusable auth session is unavailable.',
          exitCode: ExitCodes.auth,
        );
      }
      return (jsonDecode(body) as Map<String, dynamic>).cast<String, Object?>();
    } finally {
      client.close(force: true);
    }
  }

  static Directory _defaultStateDirectory() {
    final runtime = Platform.environment['XDG_RUNTIME_DIR'];
    if (runtime != null && runtime.trim().isNotEmpty) {
      return Directory('$runtime/klas-cli');
    }
    final stateHome = Platform.environment['XDG_STATE_HOME'];
    if (stateHome != null && stateHome.trim().isNotEmpty) {
      return Directory('$stateHome/klas-cli');
    }
    final home = Platform.environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      throw const CliException(
        code: 'INTERNAL_ERROR',
        message: 'Cannot determine a local state directory for auth session storage.',
        exitCode: ExitCodes.software,
      );
    }
    return Directory('$home/.local/state/klas-cli');
  }

  static Future<Process> _defaultDaemonLauncher(String metadataPath) {
    final command = _daemonCommand(metadataPath);
    return Process.start(
      command.executable,
      command.arguments,
      mode: ProcessStartMode.detachedWithStdio,
    );
  }

  static _DaemonCommand _daemonCommand(String metadataPath) {
    final resolvedExecutable = Platform.resolvedExecutable;
    final isDartVm = resolvedExecutable.endsWith('/dart') ||
        resolvedExecutable.endsWith('\\dart.exe');
    if (isDartVm) {
      return _DaemonCommand(
        executable: resolvedExecutable,
        arguments: <String>[
          Platform.script.toFilePath(),
          '__authd',
          '--metadata-file',
          metadataPath,
        ],
      );
    }

    return _DaemonCommand(
      executable: resolvedExecutable,
      arguments: <String>['__authd', '--metadata-file', metadataPath],
    );
  }
}

Future<int> runAuthSessionDaemon({required String metadataFilePath}) async {
  final credentialsRaw = stdin.readLineSync();
  if (credentialsRaw == null || credentialsRaw.trim().isEmpty) {
    stderr.writeln('Missing session credentials payload.');
    return ExitCodes.usage;
  }

  final credentials = SessionCredentials.fromJson(
    (jsonDecode(credentialsRaw) as Map<String, dynamic>).cast<String, Object?>(),
  );
  final token = _randomToken();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final metadata = AuthSessionMetadata(
    schemaVersion: '1.0',
    port: server.port,
    token: token,
    pid: pid,
    createdAt: DateTime.now().toIso8601String(),
  );

    final metadataFile = File(metadataFilePath);
    await metadataFile.parent.create(recursive: true);
    await metadataFile.writeAsString(metadata.encode());

  ProcessSignal.sigterm.watch().listen((_) async {
    await server.close(force: true);
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }
    exit(0);
  });

  await for (final request in server) {
    if (request.headers.value(HttpHeaders.authorizationHeader) !=
        'Bearer $token') {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      continue;
    }

    final response = switch ('${request.method} ${request.uri.path}') {
      'GET /v1/status' => <String, Object?>{
          'authenticated': true,
          'created_at': metadata.createdAt,
          'pid': metadata.pid,
        },
      'GET /v1/credentials' => credentials.toJson(),
      'POST /v1/logout' => <String, Object?>{'ok': true},
      _ => null,
    };

     if (response == null) {
       request.response.statusCode = HttpStatus.notFound;
       await request.response.close();
       continue;
     }

     request.response.headers.contentType = ContentType.json;
     request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
     request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
     request.response.write(jsonEncode(response));
     await request.response.close();

    if (request.method == 'POST' && request.uri.path == '/v1/logout') {
      await server.close(force: true);
      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }
      return ExitCodes.success;
    }
  }
  return ExitCodes.success;
}

String _randomToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes);
}

final class _DaemonCommand {
  const _DaemonCommand({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}
