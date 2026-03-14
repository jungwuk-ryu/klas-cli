import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klas_cli/src/auth/terminal.dart';
import 'package:klas_cli/src/auth/session_manager.dart';
import 'package:klas_cli/src/auth/session_metadata.dart';
import 'package:klas_cli/src/services/klas_service.dart';
import 'package:klasflow/klasflow.dart';
import 'package:test/test.dart';

void main() {
  const modulus =
      'd3b0a5d2e6f8c1b4998e77aa31bc4d2f3a7cb9e1ffacde099812f3aa1c8d9e07'
      '84a79b7654f0cc22a1346d8eaf3b70c9d11be9ee02baf7a90876efbda12340fd'
      'c7a8f9d01234abcdeffedcba98765432100112233445566778899aabbccddeeff';

  test(
    'auth status silently reuses environment credentials when available',
    () async {
      final service = KlasflowService(
        terminal: _SilentTerminal(),
        sessionManager: _MemorySessionManager(),
        environment: const <String, String>{
          'KLAS_ID': 'test-user',
          'KLAS_PASSWORD': 'test-password',
        },
        clientFactory: () => KlasClient(
          config: KlasClientConfig(baseUri: Uri.parse('https://example.com')),
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/usr/cmn/login/LoginSecurity.do':
                return _jsonResponse({
                  'data': {
                    'publicKeyModulus': modulus,
                    'publicKeyExponent': '10001',
                    'loginToken': 'nonce-1',
                  },
                });
              case '/usr/cmn/login/LoginCaptcha.do':
                return http.Response('OK', 200);
              case '/usr/cmn/login/LoginConfirm.do':
                return _jsonResponse({'success': true});
              case '/std/cmn/frame/KlasStop.do':
                return _utf8TextResponse(
                  '<html><head><title>KLAS</title></head></html>',
                  200,
                  headers: {'content-type': 'text/html; charset=utf-8'},
                );
              case '/std/cmn/frame/YearhakgiAtnlcSbjectList.do':
                return _jsonResponse({
                  'data': [
                    {
                      'selectYearhakgi': '20261',
                      'selectSubj': 'CSE101',
                      'selectChangeYn': 'N',
                      'isDefault': true,
                      'subjectName': '자료구조 - 김교수',
                    },
                  ],
                });
              case '/api/v1/session/info':
                return _jsonResponse({
                  'authenticated': true,
                  'userId': 'test-user',
                  'userName': '테스터',
                });
              default:
                return http.Response('Not Found', 404);
            }
          }),
        ),
      );

      final payload = await service.authStatus();

      expect(payload.data.authenticated, isTrue);
      expect(payload.data.reusable, isTrue);
      expect(payload.data.credentialSource, 'env');
    },
  );

  test(
    'profile loads successfully from environment credentials without prompting',
    () async {
      final terminal = _SilentTerminal();
      final service = KlasflowService(
        terminal: terminal,
        sessionManager: _MemorySessionManager(),
        environment: const <String, String>{
          'KLAS_ID': 'test-user',
          'KLAS_PASSWORD': 'test-password',
        },
        clientFactory: () => KlasClient(
          config: KlasClientConfig(baseUri: Uri.parse('https://example.com')),
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/usr/cmn/login/LoginSecurity.do':
                return _jsonResponse({
                  'data': {
                    'publicKeyModulus': modulus,
                    'publicKeyExponent': '10001',
                    'loginToken': 'nonce-1',
                  },
                });
              case '/usr/cmn/login/LoginCaptcha.do':
                return http.Response('OK', 200);
              case '/usr/cmn/login/LoginConfirm.do':
                return _jsonResponse({'success': true});
              case '/std/cmn/frame/KlasStop.do':
                return _utf8TextResponse(
                  '<html><head><title>KLAS</title></head></html>',
                  200,
                  headers: {'content-type': 'text/html; charset=utf-8'},
                );
              case '/std/cmn/frame/YearhakgiAtnlcSbjectList.do':
                return _jsonResponse({
                  'data': [
                    {
                      'selectYearhakgi': '20261',
                      'selectSubj': 'CSE101',
                      'selectChangeYn': 'N',
                      'isDefault': true,
                      'subjectName': '자료구조 - 김교수',
                    },
                  ],
                });
              case '/api/v1/session/info':
                return _jsonResponse({
                  'authenticated': true,
                  'userId': 'test-user',
                  'userName': '테스터',
                });
              case '/std/ads/admst/IdModifySpvInfo.do':
                return _jsonResponse({
                  'kname': '테스터',
                  'emailId': 'tester',
                  'emailHost': 'example.com',
                  'handPhoneno': '010-0000-0000',
                  'birthday': '2000-01-02',
                });
              default:
                return http.Response('Not Found', 404);
            }
          }),
        ),
      );

      final payload = await service.profile(allowPrompt: false);

      expect(payload.data.name, '테스터');
      expect(payload.data.email, 'tester@example.com');
      expect(payload.data.mobilePhone, '010-0000-0000');
      expect(terminal.promptCount, 0);
    },
  );

  test('auth status uses stored local session when available', () async {
    final sessionManager = _MemorySessionManager(
      credentials: const SessionCredentials(
        id: 'test-user',
        password: 'test-password',
      ),
    );
    final service = KlasflowService(
      terminal: _SilentTerminal(),
      sessionManager: sessionManager,
      environment: const <String, String>{},
      clientFactory: () => KlasClient(
        config: KlasClientConfig(baseUri: Uri.parse('https://example.com')),
        httpClient: MockClient((request) async {
          switch (request.url.path) {
            case '/usr/cmn/login/LoginSecurity.do':
              return _jsonResponse({
                'data': {
                  'publicKeyModulus': modulus,
                  'publicKeyExponent': '10001',
                  'loginToken': 'nonce-1',
                },
              });
            case '/usr/cmn/login/LoginCaptcha.do':
              return http.Response('OK', 200);
            case '/usr/cmn/login/LoginConfirm.do':
              return _jsonResponse({'success': true});
            case '/std/cmn/frame/KlasStop.do':
              return _utf8TextResponse(
                '<html><head><title>KLAS</title></head></html>',
                200,
              );
            case '/std/cmn/frame/YearhakgiAtnlcSbjectList.do':
              return _jsonResponse({
                'data': [
                  {
                    'selectYearhakgi': '20261',
                    'selectSubj': 'CSE101',
                    'selectChangeYn': 'N',
                    'isDefault': true,
                    'subjectName': '자료구조 - 김교수',
                  },
                ],
              });
            case '/api/v1/session/info':
              return _jsonResponse({
                'authenticated': true,
                'userId': 'test-user',
                'userName': '테스터',
              });
            default:
              return http.Response('Not Found', 404);
          }
        }),
      ),
    );

    final payload = await service.authStatus();

    expect(payload.data.authenticated, isTrue);
    expect(payload.data.credentialSource, 'session');
  });

  test(
    'login stores reusable local session after successful authentication',
    () async {
      final sessionManager = _MemorySessionManager();
      final service = KlasflowService(
        terminal: _SilentTerminal(),
        sessionManager: sessionManager,
        environment: const <String, String>{
          'KLAS_ID': 'test-user',
          'KLAS_PASSWORD': 'test-password',
        },
        clientFactory: () => KlasClient(
          config: KlasClientConfig(baseUri: Uri.parse('https://example.com')),
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/usr/cmn/login/LoginSecurity.do':
                return _jsonResponse({
                  'data': {
                    'publicKeyModulus': modulus,
                    'publicKeyExponent': '10001',
                    'loginToken': 'nonce-1',
                  },
                });
              case '/usr/cmn/login/LoginCaptcha.do':
                return http.Response('OK', 200);
              case '/usr/cmn/login/LoginConfirm.do':
                return _jsonResponse({'success': true});
              case '/std/cmn/frame/KlasStop.do':
                return _utf8TextResponse(
                  '<html><head><title>KLAS</title></head></html>',
                  200,
                  headers: {'content-type': 'text/html; charset=utf-8'},
                );
              case '/std/cmn/frame/YearhakgiAtnlcSbjectList.do':
                return _jsonResponse({
                  'data': [
                    {
                      'selectYearhakgi': '20261',
                      'selectSubj': 'CSE101',
                      'selectChangeYn': 'N',
                      'isDefault': true,
                      'subjectName': '자료구조 - 김교수',
                    },
                  ],
                });
              case '/api/v1/session/info':
                return _jsonResponse({
                  'authenticated': true,
                  'userId': 'test-user',
                  'userName': '테스터',
                });
              default:
                return http.Response('Not Found', 404);
            }
          }),
        ),
      );

      final payload = await service.login(
        allowPrompt: false,
        useStdinJson: false,
      );

      expect(payload.data.authenticated, isTrue);
      expect(sessionManager.credentials, isNotNull);
      expect(sessionManager.credentials!.id, 'test-user');
      expect(sessionManager.credentials!.password, 'test-password');
    },
  );

  test(
    'profile falls back to environment after invalid stored session',
    () async {
      final sessionManager = _MemorySessionManager(
        credentials: const SessionCredentials(
          id: 'bad-user',
          password: 'bad-password',
        ),
      );
      var loginAttempts = 0;
      final service = KlasflowService(
        terminal: _SilentTerminal(),
        sessionManager: sessionManager,
        environment: const <String, String>{
          'KLAS_ID': 'env-user',
          'KLAS_PASSWORD': 'env-password',
        },
        clientFactory: () => KlasClient(
          config: KlasClientConfig(baseUri: Uri.parse('https://example.com')),
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/usr/cmn/login/LoginSecurity.do':
                loginAttempts++;
                return _jsonResponse({
                  'data': {
                    'publicKeyModulus': modulus,
                    'publicKeyExponent': '10001',
                    'loginToken': loginAttempts == 1
                        ? 'bad-nonce'
                        : 'good-nonce',
                  },
                });
              case '/usr/cmn/login/LoginCaptcha.do':
                return http.Response('OK', 200);
              case '/usr/cmn/login/LoginConfirm.do':
                if (loginAttempts == 1) {
                  return _jsonResponse({'error': 'invalid'}, statusCode: 401);
                }
                return _jsonResponse({'success': true});
              case '/std/cmn/frame/KlasStop.do':
                return _utf8TextResponse(
                  '<html><head><title>KLAS</title></head></html>',
                  200,
                );
              case '/std/cmn/frame/YearhakgiAtnlcSbjectList.do':
                return _jsonResponse({
                  'data': [
                    {
                      'selectYearhakgi': '20261',
                      'selectSubj': 'CSE101',
                      'selectChangeYn': 'N',
                      'isDefault': true,
                      'subjectName': '자료구조 - 김교수',
                    },
                  ],
                });
              case '/api/v1/session/info':
                return _jsonResponse({
                  'authenticated': true,
                  'userId': 'env-user',
                  'userName': '테스터',
                });
              case '/std/ads/admst/IdModifySpvInfo.do':
                return _jsonResponse({'kname': '테스터'});
              default:
                return http.Response('Not Found', 404);
            }
          }),
        ),
      );

      final payload = await service.profile(allowPrompt: false);

      expect(payload.data.authenticated, isTrue);
      expect(payload.data.name, '테스터');
      expect(sessionManager.credentials, isNull);
    },
  );

  test(
    'auth status falls back to environment when stored session is invalid',
    () async {
      final sessionManager = _MemorySessionManager(
        credentials: const SessionCredentials(
          id: 'bad-user',
          password: 'bad-password',
        ),
      );
      var loginAttempts = 0;
      final service = KlasflowService(
        terminal: _SilentTerminal(),
        sessionManager: sessionManager,
        environment: const <String, String>{
          'KLAS_ID': 'env-user',
          'KLAS_PASSWORD': 'env-password',
        },
        clientFactory: () => KlasClient(
          config: KlasClientConfig(baseUri: Uri.parse('https://example.com')),
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/usr/cmn/login/LoginSecurity.do':
                loginAttempts++;
                return _jsonResponse({
                  'data': {
                    'publicKeyModulus': modulus,
                    'publicKeyExponent': '10001',
                    'loginToken': loginAttempts == 1
                        ? 'bad-nonce'
                        : 'good-nonce',
                  },
                });
              case '/usr/cmn/login/LoginCaptcha.do':
                return http.Response('OK', 200);
              case '/usr/cmn/login/LoginConfirm.do':
                if (loginAttempts == 1) {
                  return _jsonResponse({'error': 'invalid'}, statusCode: 401);
                }
                return _jsonResponse({'success': true});
              case '/std/cmn/frame/KlasStop.do':
                return _utf8TextResponse(
                  '<html><head><title>KLAS</title></head></html>',
                  200,
                );
              case '/std/cmn/frame/YearhakgiAtnlcSbjectList.do':
                return _jsonResponse({
                  'data': [
                    {
                      'selectYearhakgi': '20261',
                      'selectSubj': 'CSE101',
                      'selectChangeYn': 'N',
                      'isDefault': true,
                      'subjectName': '자료구조 - 김교수',
                    },
                  ],
                });
              case '/api/v1/session/info':
                return _jsonResponse({
                  'authenticated': true,
                  'userId': 'env-user',
                  'userName': '테스터',
                });
              default:
                return http.Response('Not Found', 404);
            }
          }),
        ),
      );

      final payload = await service.authStatus();

      expect(payload.data.authenticated, isTrue);
      expect(payload.data.credentialSource, 'env');
      expect(payload.data.reusable, isTrue);
      expect(sessionManager.credentials, isNull);
    },
  );

  test(
    'monthly schedule table rows map into normalized schedule views',
    () async {
      final service = KlasflowService(
        terminal: _SilentTerminal(),
        sessionManager: _MemorySessionManager(
          credentials: const SessionCredentials(
            id: 'test-user',
            password: 'test-password',
          ),
        ),
        environment: const <String, String>{},
        clientFactory: () => KlasClient(
          config: KlasClientConfig(baseUri: Uri.parse('https://example.com')),
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/usr/cmn/login/LoginSecurity.do':
                return _jsonResponse({
                  'data': {
                    'publicKeyModulus': modulus,
                    'publicKeyExponent': '10001',
                    'loginToken': 'nonce-1',
                  },
                });
              case '/usr/cmn/login/LoginCaptcha.do':
                return http.Response('OK', 200);
              case '/usr/cmn/login/LoginConfirm.do':
                return _jsonResponse({'success': true});
              case '/std/cmn/frame/KlasStop.do':
                return _utf8TextResponse('<html><body>ok</body></html>', 200);
              case '/std/cmn/frame/YearhakgiAtnlcSbjectList.do':
                return _jsonResponse({
                  'data': [
                    {
                      'selectYearhakgi': '20261',
                      'selectSubj': 'CSE101',
                      'selectChangeYn': 'N',
                      'isDefault': true,
                      'subjectName': '자료구조 - 김교수',
                    },
                  ],
                });
              case '/api/v1/session/info':
                return _jsonResponse({
                  'authenticated': true,
                  'userId': 'test-user',
                  'userName': '테스터',
                });
              case '/std/cmn/frame/StdHome.do':
                return _utf8TextResponse('<html><body>ok</body></html>', 200);
              case '/std/ads/admst/MySchdulMonthTableList.do':
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(body['schdulYear'], 2026);
                expect(body['schdulMonth'], 4);
                return http.Response(
                  jsonEncode([
                    {
                      'started': '2026-04-20',
                      'dayname': '1',
                      'schdulTitle': '중간고사',
                      'typeNm': '학사일정',
                    },
                  ]),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              default:
                return http.Response('Not Found', 404);
            }
          }),
        ),
      );

      final payload = await service.scheduleMonth(
        allowPrompt: false,
        year: 2026,
        month: 4,
      );

      expect(payload.meta['basis'], 'monthly_schedule_table');
      expect(payload.meta['year'], 2026);
      expect(payload.meta['month'], 4);
      expect(payload.data, hasLength(1));
      expect(payload.data.first.source, 'monthly_schedule_table');
      expect(payload.data.first.dayOfWeek, '월');
      expect(payload.data.first.title, '중간고사');
      expect(payload.data.first.startsAt, '2026-04-20T00:00:00.000');
      expect(payload.data.first.status, '학사일정');
    },
  );
}

final class _SilentTerminal implements Terminal {
  int promptCount = 0;

  @override
  bool get canPrompt => false;

  @override
  Future<String?> prompt(String message, {bool secret = false}) async {
    promptCount++;
    return null;
  }

  @override
  void writeErr(String message) {}

  @override
  void writeOut(String message) {}
}

final class _MemorySessionManager implements AuthSessionManager {
  _MemorySessionManager({this.credentials});

  SessionCredentials? credentials;

  @override
  Future<void> clear() async {
    credentials = null;
  }

  @override
  Future<bool> hasSession() async => credentials != null;

  @override
  Future<SessionCredentials?> load() async => credentials;

  @override
  Future<void> save(SessionCredentials newCredentials) async {
    credentials = newCredentials;
  }
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}

http.Response _utf8TextResponse(
  String body,
  int statusCode, {
  Map<String, String>? headers,
}) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: headers ?? const <String, String>{},
  );
}
