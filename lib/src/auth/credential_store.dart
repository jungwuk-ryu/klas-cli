import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../errors/cli_errors.dart';
import 'session_metadata.dart';

abstract interface class CredentialStore {
  String get backendLabel;

  Future<void> save(SessionCredentials credentials);

  Future<SessionCredentials?> load();

  Future<bool> hasCredentials();

  Future<void> clear();
}

abstract interface class MasterKeyStore {
  String get backendLabel;

  Future<bool> isAvailable();

  Future<void> save(String encodedKey);

  Future<String?> load();

  Future<void> clear();
}

final class PersistentCredentialStore implements CredentialStore {
  PersistentCredentialStore({
    required Directory stateDirectory,
    List<MasterKeyStore>? keyStores,
  }) : _stateDirectory = stateDirectory,
       _keyStores =
           keyStores ??
           _defaultKeyStores(
             stateDirectory: stateDirectory,
             namespace: _namespaceForDirectory(stateDirectory.path),
           );

  static const _schemaVersion = '1.0';

  final Directory _stateDirectory;
  final List<MasterKeyStore> _keyStores;

  File get _credentialsFile =>
      File('${_stateDirectory.path}/auth-credentials.enc.json');

  @override
  String get backendLabel => 'encrypted_file';

  @override
  Future<void> save(SessionCredentials credentials) async {
    await _stateDirectory.create(recursive: true);
    await _ensureSecureDirectory(_stateDirectory);

    final envelope = await _readEnvelope();
    final keyRecord = await _loadOrCreateKeyRecord(
      preferredBackend: envelope?.keyBackend,
    );
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(base64Decode(keyRecord.encodedKey));
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      utf8.encode(jsonEncode(credentials.toJson())),
      secretKey: secretKey,
      nonce: nonce,
    );

    final nextEnvelope = _CredentialEnvelope(
      schemaVersion: _schemaVersion,
      keyBackend: keyRecord.backendLabel,
      nonce: base64Encode(secretBox.nonce),
      cipherText: base64Encode(secretBox.cipherText),
      mac: base64Encode(secretBox.mac.bytes),
    );
    await _writeSecureFile(_credentialsFile, nextEnvelope.encode());
  }

  @override
  Future<SessionCredentials?> load() async {
    final envelope = await _readEnvelope();
    if (envelope == null) {
      return null;
    }

    final encodedKey = await _loadKeyForBackend(envelope.keyBackend);
    if (encodedKey == null) {
      return null;
    }

    try {
      final algorithm = AesGcm.with256bits();
      final clearText = await algorithm.decrypt(
        SecretBox(
          base64Decode(envelope.cipherText),
          nonce: base64Decode(envelope.nonce),
          mac: Mac(base64Decode(envelope.mac)),
        ),
        secretKey: SecretKey(base64Decode(encodedKey)),
      );
      final decoded =
          jsonDecode(utf8.decode(clearText)) as Map<String, Object?>;
      return SessionCredentials.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> hasCredentials() async {
    if (!await _credentialsFile.exists()) {
      return false;
    }
    final envelope = await _readEnvelope();
    if (envelope == null) {
      return false;
    }
    return (await _loadKeyForBackend(envelope.keyBackend)) != null;
  }

  @override
  Future<void> clear() async {
    for (final store in _keyStores) {
      try {
        await store.clear();
      } catch (_) {
        // best-effort cleanup continues
      }
    }
    if (await _credentialsFile.exists()) {
      await _credentialsFile.delete();
    }
  }

  Future<_StoredKeyRecord> _loadOrCreateKeyRecord({
    String? preferredBackend,
  }) async {
    final preferred = await _loadKeyForBackend(preferredBackend);
    if (preferred != null && preferredBackend != null) {
      return _StoredKeyRecord(preferredBackend, preferred);
    }

    for (final store in _keyStores) {
      final existing = await _safeLoad(store);
      if (existing != null) {
        return _StoredKeyRecord(store.backendLabel, existing);
      }
    }

    final key = _randomKey();
    for (final store in _keyStores) {
      if (!await store.isAvailable()) {
        continue;
      }
      try {
        await store.save(key);
        return _StoredKeyRecord(store.backendLabel, key);
      } catch (_) {
        continue;
      }
    }

    throw const CliException(
      code: 'INTERNAL_ERROR',
      message:
          'No local credential store is available for durable auth storage.',
      exitCode: ExitCodes.software,
      hint:
          'Check local credential-store availability or retry in a normal user session.',
    );
  }

  Future<String?> _loadKeyForBackend(String? backendLabel) async {
    if (backendLabel != null) {
      for (final store in _keyStores) {
        if (store.backendLabel != backendLabel) {
          continue;
        }
        return _safeLoad(store);
      }
    }

    for (final store in _keyStores) {
      final value = await _safeLoad(store);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  Future<_CredentialEnvelope?> _readEnvelope() async {
    if (!await _credentialsFile.exists()) {
      return null;
    }
    try {
      await _ensureSecureDirectory(_stateDirectory);
      await _ensureSecureFile(_credentialsFile);
      return _CredentialEnvelope.decode(await _credentialsFile.readAsString());
    } catch (_) {
      return null;
    }
  }

  static List<MasterKeyStore> _defaultKeyStores({
    required Directory stateDirectory,
    required String namespace,
  }) {
    final stores = <MasterKeyStore>[];
    if (Platform.isMacOS) {
      stores.add(MacOsKeychainStore(namespace: namespace));
    }
    if (Platform.isLinux) {
      stores.add(LinuxSecretToolStore(namespace: namespace));
    }
    if (Platform.isWindows) {
      stores.add(WindowsDpapiStore(stateDirectory: stateDirectory));
    }
    stores.add(FileMasterKeyStore(stateDirectory: stateDirectory));
    return stores;
  }

  static String _randomKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  Future<String?> _safeLoad(MasterKeyStore store) async {
    try {
      return await store.load();
    } catch (_) {
      return null;
    }
  }
}

final class MacOsKeychainStore implements MasterKeyStore {
  MacOsKeychainStore({required String namespace})
    : _service = 'klas-cli-$namespace';

  final String _service;
  static const _account = 'durable-master-key';

  @override
  String get backendLabel => 'macos_keychain';

  @override
  Future<void> clear() async {
    if (!Platform.isMacOS) {
      return;
    }
    await Process.run('security', <String>[
      'delete-generic-password',
      '-s',
      _service,
      '-a',
      _account,
    ]);
  }

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isMacOS) {
      return false;
    }
    final result = await Process.run('security', <String>['list-keychains']);
    return result.exitCode == 0;
  }

  @override
  Future<String?> load() async {
    if (!Platform.isMacOS) {
      return null;
    }
    final result = await Process.run('security', <String>[
      'find-generic-password',
      '-s',
      _service,
      '-a',
      _account,
      '-w',
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    final value = (result.stdout as String).trim();
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> save(String encodedKey) async {
    if (!Platform.isMacOS) {
      throw const CliException(
        code: 'INTERNAL_ERROR',
        message: 'macOS keychain backend is unavailable on this platform.',
        exitCode: ExitCodes.software,
      );
    }
    final process = await Process.start('security', <String>[
      'add-generic-password',
      '-U',
      '-s',
      _service,
      '-a',
      _account,
      '-w',
    ]);
    process.stdin.writeln(encodedKey);
    process.stdin.writeln(encodedKey);
    await process.stdin.close();
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw const CliException(
        code: 'INTERNAL_ERROR',
        message:
            'Failed to store the local auth encryption key in macOS Keychain.',
        exitCode: ExitCodes.software,
      );
    }
  }
}

final class LinuxSecretToolStore implements MasterKeyStore {
  LinuxSecretToolStore({required String namespace})
    : _attributes = <String>[
        'service',
        'klas-cli',
        'account',
        'durable-master-key',
        'namespace',
        namespace,
      ];

  final List<String> _attributes;

  @override
  String get backendLabel => 'linux_secret_service';

  @override
  Future<void> clear() async {
    if (!Platform.isLinux) {
      return;
    }
    await Process.run('secret-tool', <String>['clear', ..._attributes]);
  }

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isLinux) {
      return false;
    }
    try {
      final result = await Process.run('secret-tool', <String>[
        'search',
        ..._attributes,
      ]);
      return result.exitCode == 0 || result.exitCode == 1;
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<String?> load() async {
    if (!Platform.isLinux) {
      return null;
    }
    try {
      final result = await Process.run('secret-tool', <String>[
        'lookup',
        ..._attributes,
      ]);
      if (result.exitCode != 0) {
        return null;
      }
      final value = (result.stdout as String).trim();
      return value.isEmpty ? null : value;
    } on ProcessException {
      return null;
    }
  }

  @override
  Future<void> save(String encodedKey) async {
    if (!Platform.isLinux) {
      throw const CliException(
        code: 'INTERNAL_ERROR',
        message:
            'Linux secret-service backend is unavailable on this platform.',
        exitCode: ExitCodes.software,
      );
    }

    final process = await Process.start('secret-tool', <String>[
      'store',
      '--label',
      'klas-cli durable auth master key',
      ..._attributes,
    ]);
    process.stdin.write(encodedKey);
    await process.stdin.close();
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw const CliException(
        code: 'INTERNAL_ERROR',
        message:
            'Failed to store the local auth encryption key in Secret Service.',
        exitCode: ExitCodes.software,
      );
    }
  }
}

String _namespaceForDirectory(String path) {
  const offsetBasis = 1469598103934665603;
  const prime = 1099511628211;
  var hash = offsetBasis;
  for (final byte in utf8.encode(path)) {
    hash ^= byte;
    hash = (hash * prime) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16);
}

final class WindowsDpapiStore implements MasterKeyStore {
  WindowsDpapiStore({required Directory stateDirectory})
    : _stateDirectory = stateDirectory;

  final Directory _stateDirectory;

  File get _blobFile => File('${_stateDirectory.path}/auth-master-key.dpapi');

  @override
  String get backendLabel => 'windows_dpapi';

  @override
  Future<void> clear() async {
    if (await _blobFile.exists()) {
      await _blobFile.delete();
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final result = await Process.run('powershell', <String>[
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'$PSVersionTable.PSVersion.ToString()',
      ]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<String?> load() async {
    if (!Platform.isWindows || !await _blobFile.exists()) {
      return null;
    }
    final blob = await _blobFile.readAsString();
    if (blob.trim().isEmpty) {
      return null;
    }

    final process = await Process.start('powershell', <String>[
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'$encrypted = [Console]::In.ReadToEnd();'
          r'$secure = ConvertTo-SecureString -String $encrypted;'
          r'$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure);'
          r'try { [Console]::Out.Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)) }'
          r' finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }',
    ]);
    process.stdin.write(blob);
    await process.stdin.close();
    final output = await utf8.decodeStream(process.stdout);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      return null;
    }
    final value = output.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> save(String encodedKey) async {
    if (!Platform.isWindows) {
      throw const CliException(
        code: 'INTERNAL_ERROR',
        message: 'Windows DPAPI backend is unavailable on this platform.',
        exitCode: ExitCodes.software,
      );
    }
    await _stateDirectory.create(recursive: true);
    final process = await Process.start('powershell', <String>[
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'$plain = [Console]::In.ReadToEnd();'
          r'$secure = ConvertTo-SecureString -String $plain -AsPlainText -Force;'
          r'[Console]::Out.Write((ConvertFrom-SecureString -SecureString $secure))',
    ]);
    process.stdin.write(encodedKey);
    await process.stdin.close();
    final encrypted = await utf8.decodeStream(process.stdout);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw const CliException(
        code: 'INTERNAL_ERROR',
        message:
            'Failed to protect the local auth encryption key with Windows DPAPI.',
        exitCode: ExitCodes.software,
      );
    }
    await _blobFile.writeAsString(encrypted.trim());
  }
}

final class FileMasterKeyStore implements MasterKeyStore {
  FileMasterKeyStore({required Directory stateDirectory})
    : _stateDirectory = stateDirectory;

  final Directory _stateDirectory;

  File get _keyFile => File('${_stateDirectory.path}/auth-master-key');

  @override
  String get backendLabel => 'local_encrypted_file';

  @override
  Future<void> clear() async {
    if (await _keyFile.exists()) {
      await _keyFile.delete();
    }
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String?> load() async {
    if (!await _keyFile.exists()) {
      return null;
    }
    try {
      await _ensureSecureDirectory(_stateDirectory);
      await _ensureSecureFile(_keyFile);
      final value = (await _keyFile.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String encodedKey) async {
    await _writeSecureFile(_keyFile, encodedKey);
  }
}

Future<void> _writeSecureFile(File file, String contents) async {
  await file.parent.create(recursive: true);
  await _ensureSecureDirectory(file.parent);
  final tempFile = File('${file.path}.tmp');
  await tempFile.writeAsString(contents);
  await _ensureSecureFile(tempFile);
  await tempFile.rename(file.path);
  await _ensureSecureFile(file);
}

Future<void> _ensureSecureDirectory(Directory directory) async {
  await _setOwnerOnlyPermissions(directory.path, isDirectory: true);
}

Future<void> _ensureSecureFile(File file) async {
  await _setOwnerOnlyPermissions(file.path, isDirectory: false);
}

Future<void> _setOwnerOnlyPermissions(
  String path, {
  required bool isDirectory,
}) async {
  if (Platform.isWindows) {
    return;
  }
  final result = await Process.run('chmod', <String>[
    isDirectory ? '700' : '600',
    path,
  ]);
  if (result.exitCode != 0) {
    final hint = (result.stderr as String).trim();
    throw CliException(
      code: 'INTERNAL_ERROR',
      message: 'Failed to protect local auth storage.',
      exitCode: ExitCodes.software,
      hint: hint.isEmpty ? null : hint,
    );
  }
}

final class _StoredKeyRecord {
  const _StoredKeyRecord(this.backendLabel, this.encodedKey);

  final String backendLabel;
  final String encodedKey;
}

final class _CredentialEnvelope {
  const _CredentialEnvelope({
    required this.schemaVersion,
    required this.keyBackend,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final String schemaVersion;
  final String keyBackend;
  final String nonce;
  final String cipherText;
  final String mac;

  String encode() => jsonEncode(<String, Object?>{
    'schema_version': schemaVersion,
    'key_backend': keyBackend,
    'nonce': nonce,
    'cipher_text': cipherText,
    'mac': mac,
  });

  static _CredentialEnvelope decode(String raw) {
    final json = (jsonDecode(raw) as Map<String, dynamic>)
        .cast<String, Object?>();
    final nonce = json['nonce'] as String?;
    final cipherText = json['cipher_text'] as String?;
    final mac = json['mac'] as String?;
    final keyBackend = json['key_backend'] as String?;
    if (nonce == null ||
        cipherText == null ||
        mac == null ||
        keyBackend == null) {
      throw const FormatException('Invalid credential envelope.');
    }
    return _CredentialEnvelope(
      schemaVersion: json['schema_version'] as String? ?? '1.0',
      keyBackend: keyBackend,
      nonce: nonce,
      cipherText: cipherText,
      mac: mac,
    );
  }
}
