import 'dart:convert';
import 'dart:io';

import 'package:klas_cli/src/auth/credential_store.dart';
import 'package:klas_cli/src/auth/session_metadata.dart';
import 'package:test/test.dart';

void main() {
  test(
    'persistent credential store falls back to local encrypted files',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'klas-cli-credential-store-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = PersistentCredentialStore(
        stateDirectory: tempDir,
        keyStores: <MasterKeyStore>[
          const _UnavailableKeyStore(),
          FileMasterKeyStore(stateDirectory: tempDir),
        ],
      );

      await store.save(
        const SessionCredentials(id: 'stored-user', password: 'stored-pass'),
      );

      final loaded = await store.load();
      final envelope =
          jsonDecode(
                await File(
                  '${tempDir.path}/auth-credentials.enc.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;

      expect(loaded, isNotNull);
      expect(loaded!.id, 'stored-user');
      expect(loaded.password, 'stored-pass');
      expect(envelope['key_backend'], 'local_encrypted_file');

      if (!Platform.isWindows) {
        final keyMode = await Process.run('stat', <String>[
          '-c',
          '%a',
          '${tempDir.path}/auth-master-key',
        ]);
        final credentialsMode = await Process.run('stat', <String>[
          '-c',
          '%a',
          '${tempDir.path}/auth-credentials.enc.json',
        ]);
        expect((keyMode.stdout as String).trim(), '600');
        expect((credentialsMode.stdout as String).trim(), '600');
      }
    },
  );

  test('persistent credential store ignores failing backend loads', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'klas-cli-credential-store-fallback-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = PersistentCredentialStore(
      stateDirectory: tempDir,
      keyStores: <MasterKeyStore>[
        const _ThrowingKeyStore(),
        FileMasterKeyStore(stateDirectory: tempDir),
      ],
    );

    await store.save(
      const SessionCredentials(id: 'user-2', password: 'pass-2'),
    );

    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.id, 'user-2');
    expect(loaded.password, 'pass-2');
  });
}

final class _UnavailableKeyStore implements MasterKeyStore {
  const _UnavailableKeyStore();

  @override
  String get backendLabel => 'unavailable';

  @override
  Future<void> clear() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String encodedKey) async {
    throw UnimplementedError('Store is unavailable.');
  }
}

final class _ThrowingKeyStore implements MasterKeyStore {
  const _ThrowingKeyStore();

  @override
  String get backendLabel => 'throwing';

  @override
  Future<void> clear() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String?> load() async => throw Exception('backend failure');

  @override
  Future<void> save(String encodedKey) async {
    throw Exception('backend failure');
  }
}
