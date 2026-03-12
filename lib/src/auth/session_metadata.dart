import 'dart:convert';

import '../models/cli_models.dart';

final class AuthSessionMetadata {
  const AuthSessionMetadata({
    required this.schemaVersion,
    required this.port,
    required this.token,
    required this.pid,
    required this.createdAt,
  });

  final String schemaVersion;
  final int port;
  final String token;
  final int pid;
  final String createdAt;

  JsonMap toJson() => <String, Object?>{
    'schema_version': schemaVersion,
    'port': port,
    'token': token,
    'pid': pid,
    'created_at': createdAt,
  };

  String encode() => jsonEncode(toJson());

  static AuthSessionMetadata fromJson(Map<String, Object?> json) {
    final port = json['port'] as int?;
    final token = json['token'] as String?;
    final pid = json['pid'] as int?;
    final createdAt = json['created_at'] as String?;
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException('Invalid auth session port.');
    }
    if (token == null || token.trim().length < 32) {
      throw const FormatException('Invalid auth session token.');
    }
    if (pid == null || pid <= 0) {
      throw const FormatException('Invalid auth session pid.');
    }
    if (createdAt == null || DateTime.tryParse(createdAt) == null) {
      throw const FormatException('Invalid auth session creation time.');
    }

    return AuthSessionMetadata(
      schemaVersion: json['schema_version'] as String? ?? '1.0',
      port: port,
      token: token,
      pid: pid,
      createdAt: createdAt,
    );
  }

  static AuthSessionMetadata decode(String raw) {
    return fromJson(jsonDecode(raw) as Map<String, Object?>);
  }
}

final class SessionCredentials {
  const SessionCredentials({required this.id, required this.password});

  final String id;
  final String password;

  JsonMap toJson() => <String, Object?>{'id': id, 'password': password};

  static SessionCredentials fromJson(Map<String, Object?> json) {
    return SessionCredentials(
      id: json['id'] as String,
      password: json['password'] as String,
    );
  }
}
