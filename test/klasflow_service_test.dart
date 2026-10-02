import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klas_cli/src/auth/terminal.dart';
import 'package:klas_cli/src/errors/cli_errors.dart';
import 'package:klas_cli/src/auth/session_manager.dart';
import 'package:klas_cli/src/auth/session_metadata.dart';
import 'package:klas_cli/src/models/cli_models.dart';
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
      expect(loginAttempts, 2);
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
      expect(loginAttempts, 2);
      expect(sessionManager.credentials, isNull);
    },
  );

  test(
    'profile falls back to environment after stored session expires mid-request',
    () async {
      final sessionManager = _MemorySessionManager(
        credentials: const SessionCredentials(
          id: 'session-user',
          password: 'session-password',
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
                    'loginToken': 'nonce-$loginAttempts',
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
                  'authenticated': loginAttempts > 1,
                  'userId': loginAttempts == 1 ? 'session-user' : 'env-user',
                  'userName': '테스터',
                });
              case '/std/ads/admst/IdModifySpvInfo.do':
                return _jsonResponse({
                  'kname': '테스터',
                  'emailId': 'tester',
                  'emailHost': 'example.com',
                });
              default:
                return http.Response('Not Found', 404);
            }
          }),
        ),
      );

      final payload = await service.profile(allowPrompt: false);

      expect(payload.data.authenticated, isTrue);
      expect(payload.data.name, '테스터');
      expect(payload.data.email, 'tester@example.com');
      expect(loginAttempts, 2);
      expect(sessionManager.credentials, isNull);
    },
  );

  test(
    'profile returns AUTH_REQUIRED without prompting in a non-interactive terminal',
    () async {
      final terminal = _SilentTerminal();
      final service = KlasflowService(
        terminal: terminal,
        sessionManager: _MemorySessionManager(),
        environment: const <String, String>{},
        clientFactory: () => throw StateError('client should not be created'),
      );

      await expectLater(
        () => service.profile(allowPrompt: true),
        throwsA(
          isA<CliException>()
              .having((error) => error.code, 'code', 'AUTH_REQUIRED')
              .having(
                (error) => error.message,
                'message',
                'Authentication is required for this command.',
              )
              .having((error) => error.exitCode, 'exitCode', ExitCodes.auth)
              .having(
                (error) => error.hint,
                'hint',
                'Set KLAS_ID and KLAS_PASSWORD or run the command in an interactive terminal.',
              ),
        ),
      );

      expect(terminal.promptCount, 0);
    },
  );

  test(
    'auth status restores durable session credentials when runtime metadata is missing',
    () async {
      final sessionManager = _RestoringSessionManager.missingRuntime(
        durableCredentials: const SessionCredentials(
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
      expect(payload.data.reusable, isTrue);
      expect(sessionManager.restoreCount, 1);
      expect(sessionManager.runtimeMetadata, isNotNull);
    },
  );

  test(
    'profile restores durable session credentials when runtime metadata is stale',
    () async {
      final sessionManager = _RestoringSessionManager.staleRuntime(
        durableCredentials: const SessionCredentials(
          id: 'test-user',
          password: 'test-password',
        ),
      );
      final terminal = _SilentTerminal();
      final service = KlasflowService(
        terminal: terminal,
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
                });
              default:
                return http.Response('Not Found', 404);
            }
          }),
        ),
      );

      final payload = await service.profile(allowPrompt: false);

      expect(payload.data.authenticated, isTrue);
      expect(payload.data.name, '테스터');
      expect(payload.data.email, 'tester@example.com');
      expect(payload.data.mobilePhone, '010-0000-0000');
      expect(sessionManager.restoreCount, 1);
      expect(sessionManager.runtimeMetadata, isNotNull);
      expect(terminal.promptCount, 0);
    },
  );

  test(
    'tasks list keeps successful fan-out data and sanitized warnings',
    () async {
      final service = _buildTwoCourseFanOutService((request) async {
        switch (request.url.path) {
          case '/std/lis/evltn/TaskStdList.do':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['selectYearhakgi'], '20261');
            expect(body['selectChangeYn'], 'N');

            final courseId = body['selectSubj'];
            final currentPage = body['currentPage'];
            if (courseId == 'CSE101' && currentPage == 0) {
              return _jsonAnyResponse([
                {
                  'taskNo': 7,
                  'title': '포인터 과제',
                  'startdate': '2026-03-20 09:00:00',
                  'expiredate': '2026-03-27 23:59:00',
                  'submityn': 'Y',
                },
              ]);
            }
            if (courseId == 'CSE101' && currentPage == 1) {
              return _jsonAnyResponse(const <Object>[]);
            }
            if (courseId == 'CSE102') {
              throw const NetworkException('task-secret-token');
            }
            return http.Response('Not Found', 404);
          default:
            return http.Response('Not Found', 404);
        }
      });

      final payload = await service.listTasks(allowPrompt: false);

      expect(payload.data, hasLength(1));
      expect(payload.data.single.courseId, 'CSE101');
      expect(payload.data.single.courseTitle, '자료구조');
      expect(payload.data.single.taskNo, 7);
      expect(payload.data.single.title, '포인터 과제');
      expect(payload.data.single.dueAt, '2026-03-27T23:59:00');
      expect(
        payload.data.single.submissionStatus,
        TaskSubmissionStatus.submitted,
      );
      expect(
        payload.warnings,
        equals(const <String>[
          'Failed to load tasks for 운영체제: A network or KLAS service error occurred while processing the request.',
        ]),
      );
      expect(payload.warnings.single, isNot(contains('task-secret-token')));
      expect(payload.meta['count'], 1);
      expect(payload.meta['courses_scanned'], 2);
      expect(payload.meta['course_filter'], isNull);
    },
  );

  test(
    'tasks list makes the current all-fail fan-out behavior explicit',
    () async {
      final service = _buildTwoCourseFanOutService((request) async {
        switch (request.url.path) {
          case '/std/lis/evltn/TaskStdList.do':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['selectYearhakgi'], '20261');
            expect(body['selectChangeYn'], 'N');

            final courseId = body['selectSubj'];
            if (courseId == 'CSE101') {
              throw const NetworkException('task-secret-one');
            }
            if (courseId == 'CSE102') {
              throw const NetworkException('task-secret-two');
            }
            return http.Response('Not Found', 404);
          default:
            return http.Response('Not Found', 404);
        }
      });

      await expectLater(
        () => service.listTasks(allowPrompt: false),
        throwsA(
          isA<CliException>()
              .having((error) => error.code, 'code', 'NETWORK_ERROR')
              .having(
                (error) => error.message,
                'message',
                'Failed to load tasks for every selected course.',
              )
              .having((error) => error.exitCode, 'exitCode', ExitCodes.network)
              .having((error) => error.retryable, 'retryable', isTrue)
              .having(
                (error) => error.hint,
                'hint',
                'Try again in a moment. If the problem persists, check network access to KLAS.',
              )
              .having(
                (error) => error.message,
                'sanitized message one',
                isNot(contains('task-secret-one')),
              )
              .having(
                (error) => error.message,
                'sanitized message two',
                isNot(contains('task-secret-two')),
              )
              .having(
                (error) => error.hint,
                'sanitized hint',
                isNot(contains('task-secret')),
              ),
        ),
      );
    },
  );

  test(
    'notices list keeps successful fan-out data and sanitized warnings',
    () async {
      final service = _buildTwoCourseFanOutService((request) async {
        switch (request.url.path) {
          case '/std/lis/sport/d052b8f845784c639f036b102fdc3023/BoardStdList.do':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['selectYearhakgi'], '20261');
            expect(body['selectChangeYn'], 'N');
            expect(body['searchCondition'], 'ALL');
            expect(body['searchKeyword'], '');
            expect(body['currentPage'], 0);

            final courseId = body['selectSubj'];
            if (courseId == 'CSE101') {
              return _jsonResponse({
                'list': [
                  {
                    'boardNo': 101,
                    'title': '기말 안내',
                    'userNm': '김교수',
                    'registDt': '2026-06-20 13:30:20',
                    'atchFileId': 'attach-101',
                    'fileCnt': 1,
                  },
                ],
                'page': {
                  'totalPages': 1,
                  'totalElements': 1,
                  'currentPage': 0,
                  'pageSize': 10,
                },
              });
            }
            if (courseId == 'CSE102') {
              throw const NetworkException('notice-secret-token');
            }
            return http.Response('Not Found', 404);
          default:
            return http.Response('Not Found', 404);
        }
      });

      final payload = await service.listNotices(allowPrompt: false);

      expect(payload.data, hasLength(1));
      expect(payload.data.single.courseId, 'CSE101');
      expect(payload.data.single.courseTitle, '자료구조');
      expect(payload.data.single.boardNo, 101);
      expect(payload.data.single.title, '기말 안내');
      expect(payload.data.single.authorName, '김교수');
      expect(payload.data.single.postedAt, '2026-06-20T13:30:20');
      expect(payload.data.single.hasAttachments, isTrue);
      expect(payload.data.single.fileCount, 1);
      expect(
        payload.warnings,
        equals(const <String>[
          'Failed to load notices for 운영체제: A network or KLAS service error occurred while processing the request.',
        ]),
      );
      expect(payload.warnings.single, isNot(contains('notice-secret-token')));
      expect(payload.meta['count'], 1);
      expect(payload.meta['courses_scanned'], 2);
      expect(payload.meta['course_filter'], isNull);
    },
  );

  test(
    'notices list makes the current all-fail fan-out behavior explicit',
    () async {
      final service = _buildTwoCourseFanOutService((request) async {
        switch (request.url.path) {
          case '/std/lis/sport/d052b8f845784c639f036b102fdc3023/BoardStdList.do':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['selectYearhakgi'], '20261');
            expect(body['selectChangeYn'], 'N');

            final courseId = body['selectSubj'];
            if (courseId == 'CSE101') {
              throw const NetworkException('notice-secret-one');
            }
            if (courseId == 'CSE102') {
              throw const NetworkException('notice-secret-two');
            }
            return http.Response('Not Found', 404);
          default:
            return http.Response('Not Found', 404);
        }
      });

      await expectLater(
        () => service.listNotices(allowPrompt: false),
        throwsA(
          isA<CliException>()
              .having((error) => error.code, 'code', 'NETWORK_ERROR')
              .having(
                (error) => error.message,
                'message',
                'Failed to load notices for every selected course.',
              )
              .having((error) => error.exitCode, 'exitCode', ExitCodes.network)
              .having((error) => error.retryable, 'retryable', isTrue)
              .having(
                (error) => error.hint,
                'hint',
                'Try again in a moment. If the problem persists, check network access to KLAS.',
              )
              .having(
                (error) => error.message,
                'sanitized message one',
                isNot(contains('notice-secret-one')),
              )
              .having(
                (error) => error.message,
                'sanitized message two',
                isNot(contains('notice-secret-two')),
              )
              .having(
                (error) => error.hint,
                'sanitized hint',
                isNot(contains('notice-secret')),
              ),
        ),
      );
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
  group('course bodies and attachments', () {
    test(
      'notice detail targets the selected course and normalizes wrapped data',
      () async {
        var downloads = 0;
        final service = _buildTwoCourseFanOutService((request) async {
          if (request.url.path.endsWith('/BoardStdView.do')) {
            final body = jsonDecode(request.body);
            expect(body['selectSubj'], 'CSE102');
            expect(body['boardNo'], '9');
          }
          if (request.url.path.contains('/DownloadFile/')) downloads++;
          return _courseDetailResponse(request);
        });
        final result = await service.showNotice(
          9,
          allowPrompt: false,
          courseSelector: '운영체제',
        );
        expect(result.data.courseId, 'CSE102');
        expect(result.data.title, '시험 안내');
        expect(result.data.authorName, '교수');
        expect(result.data.contentHtml, '<p>강의실 &amp; 준비물</p><p>두 번째 문단</p>');
        expect(result.data.contentText, '강의실 & 준비물\n\n두 번째 문단');
        expect(result.data.postedAt, '2026-03-10T12:00:00');
        expect(result.data.attachments, hasLength(2));
        expect(result.data.attachments!.first.fileName, '안내.pdf');
        expect(result.data.attachments!.first.sizeBytes, 3);
        expect(
          result.data.attachments!.every((file) => file.localPath == null),
          isTrue,
        );
        expect(downloads, 0);
        expect(result.warnings, isEmpty);
      },
    );

    test(
      'task detail preserves HTML and separates report and submission attachments',
      () async {
        var downloads = 0;
        final service = _buildTwoCourseFanOutService((request) async {
          if (request.url.path.endsWith('/TaskStdView.do')) {
            final body = jsonDecode(request.body);
            expect(body['selectSubj'], 'CSE101');
            expect(body['ordseq'], '12');
          }
          if (request.url.path.contains('/DownloadFile/')) downloads++;
          return _courseDetailResponse(request);
        });
        final result = await service.showTask(
          12,
          allowPrompt: false,
          courseSelector: 'CSE101',
        );
        expect(result.data.reportHtml, '<p>알고리즘을 작성하세요.</p>');
        expect(result.data.reportText, '알고리즘을 작성하세요.');
        expect(result.data.submissionText, '제출했습니다.');
        expect(result.data.attachments!.first.fileName, '안내.pdf');
        expect(result.data.submissionAttachments!.single.fileName, '답안.zip');
        expect(result.data.attachments!.first.localPath, isNull);
        expect(downloads, 0);
      },
    );

    test(
      'notice downloads authenticated bytes and never overwrites existing files',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'klas-notice-download-',
        );
        addTearDown(() => root.delete(recursive: true));
        final existing = File('${root.path}/안내.pdf');
        await existing.writeAsString('existing');
        final service = _buildTwoCourseFanOutService(_courseDetailResponse);
        final first = await service.showNotice(
          9,
          allowPrompt: false,
          courseSelector: 'CSE101',
          downloadDirectory: root.path,
        );
        final second = await service.showNotice(
          9,
          allowPrompt: false,
          courseSelector: 'CSE101',
          downloadDirectory: root.path,
        );
        expect(await existing.readAsString(), 'existing');
        final paths = [
          ...first.data.attachments!,
          ...second.data.attachments!,
        ].map((file) => file.localPath!).toList();
        expect(paths.toSet(), hasLength(4));
        for (final path in paths) {
          expect(
            path.startsWith('${root.absolute.path}${Platform.pathSeparator}'),
            isTrue,
          );
          expect(await File(path).readAsBytes(), [1, 2, 3]);
        }
        expect(first.warnings, isEmpty);
      },
    );

    test(
      'task downloads both attachment groups in distinct directories',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'klas-task-download-',
        );
        addTearDown(() => root.delete(recursive: true));
        final result = await _buildTwoCourseFanOutService(_courseDetailResponse)
            .showTask(
              12,
              allowPrompt: false,
              courseSelector: 'CSE101',
              downloadDirectory: root.path,
            );
        final report = result.data.attachments!.first.localPath!;
        final submission = result.data.submissionAttachments!.single.localPath!;
        expect(File(report).parent.path, isNot(File(submission).parent.path));
        expect(await File(submission).readAsBytes(), [1, 2, 3]);
        expect(result.warnings, isEmpty);
      },
    );

    test(
      'unsafe and duplicate attachment filenames stay inside the destination',
      () async {
        final root = await Directory.systemTemp.createTemp('klas-safe-names-');
        addTearDown(() => root.delete(recursive: true));
        final names = [
          '../../outside.txt',
          r'..\..\outside.txt',
          'CON',
          '..',
          'bad:?.txt',
          null,
        ];
        final service = _buildTwoCourseFanOutService((request) async {
          if (request.url.path.endsWith('/UploadFileList.do')) {
            return _jsonAnyResponse([
              for (var i = 0; i < names.length; i++)
                {'fileSn': '${i + 1}', 'orignlFileNm': names[i]},
            ]);
          }
          return _courseDetailResponse(request);
        });
        final result = await service.showNotice(
          9,
          allowPrompt: false,
          courseSelector: 'CSE101',
          downloadDirectory: root.path,
        );
        final paths = result.data.attachments!
            .map((file) => file.localPath!)
            .toList();
        expect(paths.toSet(), hasLength(names.length));
        for (final path in paths) {
          expect(
            path.startsWith('${root.absolute.path}${Platform.pathSeparator}'),
            isTrue,
          );
          expect(await File(path).exists(), isTrue);
        }
        expect(await File('${root.path}/outside.txt').exists(), isFalse);
      },
    );

    test(
      'absent attachment references do not fetch files or create a destination',
      () async {
        final root = await Directory.systemTemp.createTemp('klas-no-files-');
        addTearDown(() => root.delete(recursive: true));
        var fileCalls = 0;
        final service = _buildTwoCourseFanOutService((request) async {
          if (request.url.path.endsWith('/BoardStdView.do')) {
            return _jsonResponse({
              'board': {'boardNo': 9, 'contents': '<p>본문만</p>'},
            });
          }
          if (request.url.path.endsWith('/TaskStdView.do')) {
            return _jsonResponse({
              'rpt': {'contents': '<p>과제 본문</p>'},
            });
          }
          if (request.url.path.startsWith('/common/file/')) fileCalls++;
          return _courseDetailResponse(request);
        });
        final destination = '${root.path}/uncreated';
        final notice = await service.showNotice(
          9,
          allowPrompt: false,
          courseSelector: 'CSE101',
          downloadDirectory: destination,
        );
        final task = await service.showTask(
          12,
          allowPrompt: false,
          courseSelector: 'CSE101',
          downloadDirectory: destination,
        );
        expect(notice.data.contentText, '본문만');
        expect(notice.data.attachments, isEmpty);
        expect(task.data.attachments, isEmpty);
        expect(task.data.submissionAttachments, isEmpty);
        expect(fileCalls, 0);
        expect(await Directory(destination).exists(), isFalse);
      },
    );

    test(
      'file listing failure preserves the body and sanitizes warnings',
      () async {
        final service = _buildTwoCourseFanOutService((request) async {
          if (request.url.path.endsWith('/UploadFileList.do')) {
            throw const NetworkException('private-cookie-value');
          }
          return _courseDetailResponse(request);
        });
        final result = await service.showNotice(
          9,
          allowPrompt: false,
          courseSelector: 'CSE101',
        );
        expect(result.data.contentText, contains('강의실'));
        expect(result.data.attachments, isNull);
        expect(result.warnings, hasLength(1));
        expect(result.warnings.single, contains('Failed to list'));
        expect(result.warnings.single, isNot(contains('private-cookie-value')));
      },
    );

    test(
      'one attachment download failure preserves other downloads and metadata',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'klas-partial-files-',
        );
        addTearDown(() => root.delete(recursive: true));
        final service = _buildTwoCourseFanOutService((request) async {
          if (request.url.path.endsWith('/DownloadFile/report-files/1')) {
            throw const NetworkException('private-file-token');
          }
          return _courseDetailResponse(request);
        });
        final result = await service.showNotice(
          9,
          allowPrompt: false,
          courseSelector: 'CSE101',
          downloadDirectory: root.path,
        );
        expect(result.data.contentText, contains('강의실'));
        expect(result.data.attachments!.first.localPath, isNull);
        expect(
          await File(result.data.attachments!.last.localPath!).exists(),
          isTrue,
        );
        expect(result.warnings.single, contains('Failed to download'));
        expect(result.warnings.single, isNot(contains('private-file-token')));
      },
    );

    test(
      'invalid destination is a sanitized warning and does not lose the body',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'klas-invalid-directory-',
        );
        addTearDown(() => root.delete(recursive: true));
        final target = File('${root.path}/file');
        await target.writeAsString('keep');
        final result = await _buildTwoCourseFanOutService(_courseDetailResponse)
            .showNotice(
              9,
              allowPrompt: false,
              courseSelector: 'CSE101',
              downloadDirectory: target.path,
            );
        expect(result.data.contentText, contains('강의실'));
        expect(
          result.data.attachments!.every((file) => file.localPath == null),
          isTrue,
        );
        expect(result.warnings, hasLength(2));
        expect(result.warnings.first, contains('could not be saved'));
        expect(await target.readAsString(), 'keep');
      },
    );

    test(
      'unresolved attachment references produce an explicit warning',
      () async {
        final service = _buildTwoCourseFanOutService(
          (request) async => request.url.path.endsWith('/UploadFileList.do')
              ? _jsonAnyResponse([])
              : _courseDetailResponse(request),
        );
        final result = await service.showNotice(
          9,
          allowPrompt: false,
          courseSelector: 'CSE101',
        );
        expect(result.data.attachments, isEmpty);
        expect(result.warnings.single, contains('No files were returned'));
      },
    );

    test(
      'advertised files without an attachment reference remain unavailable',
      () async {
        final service = _buildTwoCourseFanOutService(
          (request) async => request.url.path.endsWith('/BoardStdView.do')
              ? _jsonResponse({
                  'board': {'boardNo': 9, 'content': '본문', 'fileCnt': 1},
                })
              : _courseDetailResponse(request),
        );
        final result = await service.showNotice(
          9,
          allowPrompt: false,
          courseSelector: 'CSE101',
        );
        expect(result.data.contentText, '본문');
        expect(result.data.hasAttachments, isTrue);
        expect(result.data.attachments, isNull);
        expect(
          result.warnings.single,
          contains('did not return an attachment reference'),
        );
      },
    );

    test(
      'missing notice and wrong notice identity return NOTICE_NOT_FOUND',
      () async {
        for (final response in <Map<String, dynamic>>[
          {},
          {'board': <String, dynamic>{}},
          {
            'board': {'boardNo': 10, 'title': '다른 공지'},
          },
        ]) {
          final service = _buildTwoCourseFanOutService(
            (request) async => request.url.path.endsWith('/BoardStdView.do')
                ? _jsonResponse(response)
                : _courseDetailResponse(request),
          );
          await expectLater(
            service.showNotice(9, allowPrompt: false, courseSelector: 'CSE101'),
            throwsA(
              isA<CliException>().having(
                (error) => error.code,
                'code',
                'NOTICE_NOT_FOUND',
              ),
            ),
          );
        }
      },
    );

    test(
      'task selection remains explicit when numbers overlap across courses',
      () async {
        final service = _buildTwoCourseFanOutService(_courseDetailResponse);
        await expectLater(
          service.showTask(12, allowPrompt: false),
          throwsA(
            isA<CliException>().having(
              (error) => error.code,
              'code',
              'AMBIGUOUS_INPUT',
            ),
          ),
        );
        await expectLater(
          service.showTask(99, allowPrompt: false, courseSelector: 'CSE101'),
          throwsA(
            isA<CliException>().having(
              (error) => error.code,
              'code',
              'TASK_NOT_FOUND',
            ),
          ),
        );
        await expectLater(
          service.showNotice(9, allowPrompt: false, courseSelector: 'unknown'),
          throwsA(
            isA<CliException>().having(
              (error) => error.code,
              'code',
              'COURSE_NOT_FOUND',
            ),
          ),
        );
      },
    );
  });
  test(
    'notice detail uses list-bound board context and attachment metadata',
    () async {
      final service = _buildTwoCourseFanOutService((request) async {
        if (request.url.path.endsWith('/BoardStdList.do')) {
          return _jsonResponse({
            'list': [
              {
                'boardNo': 9,
                'masterNo': 7,
                'title': '목록 제목',
                'userNm': '교수',
                'registDt': '2026-03-10 12:00',
                'atchFileId': 'report-files',
                'fileCnt': 2,
              },
            ],
          });
        }
        if (request.url.path.endsWith('/BoardStdView.do')) {
          expect(jsonDecode(request.body)['searchMasterNo'], '7');
          return _jsonResponse({
            'board': {'boardNo': 9, 'contents': '<p>본문</p>'},
          });
        }
        return _courseDetailResponse(request);
      });
      final result = await service.showNotice(
        9,
        allowPrompt: false,
        courseSelector: 'CSE101',
      );
      expect(result.data.title, '목록 제목');
      expect(result.data.contentText, '본문');
      expect(result.data.authorName, '교수');
      expect(result.data.attachments, hasLength(2));
      expect(result.warnings, isEmpty);
    },
  );

  test(
    'notice detail can read a known number outside the loaded list',
    () async {
      final service = _buildTwoCourseFanOutService(
        (request) async => request.url.path.endsWith('/BoardStdList.do')
            ? _jsonResponse({'list': []})
            : _courseDetailResponse(request),
      );
      final result = await service.showNotice(
        9,
        allowPrompt: false,
        courseSelector: 'CSE101',
      );
      expect(result.data.contentText, contains('강의실'));
      expect(result.data.attachments, hasLength(2));
    },
  );
}

Future<http.Response> _courseDetailResponse(http.Request request) async {
  if (request.url.path.endsWith('/BoardViewStdPage.do')) {
    return http.Response('<html>notice</html>', 200);
  }
  if (request.url.path.endsWith('/BoardStdView.do')) {
    return _jsonResponse({
      'data': {
        'detail': {
          'boardNo': 9,
          'title': '시험 안내',
          'userNm': '교수',
          'registDt': '2026-03-10 12:00',
          'fileCnt': 2,
          'atchFileId': 'report-files',
          'content': '<p>강의실 &amp; 준비물</p><p>두 번째 문단</p>',
        },
        'comments': [],
      },
    });
  }
  if (request.url.path.endsWith('/BoardStdList.do')) {
    return _jsonResponse({
      'list': [
        {'boardNo': 9, 'masterNo': 7, 'title': '시험 안내'},
      ],
    });
  }
  if (request.url.path.endsWith('/TaskStdList.do')) {
    final body = jsonDecode(request.body);
    return _jsonAnyResponse(
      body['currentPage'] == 0
          ? [
              {
                'taskNo': 12,
                'title': '알고리즘 과제',
                'expiredate': '2026-03-20',
                'submitYn': 'Y',
              },
            ]
          : [],
    );
  }
  if (request.url.path.endsWith('/TaskStdView.do')) {
    return _jsonResponse({
      'rpt': {
        'title': '알고리즘 과제',
        'contents': '<p>알고리즘을 작성하세요.</p>',
        'atchFileId': 'report-files',
      },
      'smt': {'contents': '제출했습니다.', 'fileGroupId': 'submission-files'},
    });
  }
  if (request.url.path.endsWith('/UploadFileList.do')) {
    final body = jsonDecode(request.body);
    if (body['attachId'] == 'submission-files') {
      return _jsonAnyResponse([
        {'fileSn': '1', 'fileName': '답안.zip', 'fileSize': 3},
      ]);
    }
    return _jsonAnyResponse([
      {'fileSn': '1', 'orignlFileNm': '안내.pdf', 'fileMg': 3},
      {'fileSn': '2', 'orignlFileNm': '안내.pdf', 'fileMg': 3},
    ]);
  }
  if (request.url.path.contains('/DownloadFile/')) {
    expect(request.headers['cookie'], contains('detail_session=fixture'));
    return http.Response.bytes(
      [1, 2, 3],
      200,
      headers: {'content-type': 'application/octet-stream'},
    );
  }
  return http.Response('Not Found', 404);
}

KlasflowService _buildTwoCourseFanOutService(
  Future<http.Response> Function(http.Request request) handler,
) {
  return KlasflowService(
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
                'publicKeyModulus': _helperModulus,
                'publicKeyExponent': '10001',
                'loginToken': 'nonce-1',
              },
            });
          case '/usr/cmn/login/LoginCaptcha.do':
            return http.Response('OK', 200);
          case '/usr/cmn/login/LoginConfirm.do':
            return http.Response(
              jsonEncode({'success': true}),
              200,
              headers: {
                'content-type': 'application/json; charset=utf-8',
                'set-cookie': 'detail_session=fixture; Path=/; HttpOnly',
              },
            );
          case '/std/cmn/frame/KlasStop.do':
            return _utf8TextResponse(
              '<html><head><title>KLAS</title></head></html>',
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          case '/std/cmn/frame/YearhakgiAtnlcSbjectList.do':
            return _jsonResponse({'data': _twoCourseContexts});
          case '/api/v1/session/info':
            return _jsonResponse({
              'authenticated': true,
              'userId': 'test-user',
              'userName': '테스터',
            });
          default:
            return handler(request);
        }
      }),
    ),
  );
}

const _helperModulus =
    'd3b0a5d2e6f8c1b4998e77aa31bc4d2f3a7cb9e1ffacde099812f3aa1c8d9e07'
    '84a79b7654f0cc22a1346d8eaf3b70c9d11be9ee02baf7a90876efbda12340fd'
    'c7a8f9d01234abcdeffedcba98765432100112233445566778899aabbccddeeff';

const _twoCourseContexts = <Map<String, Object?>>[
  {
    'selectYearhakgi': '20261',
    'selectSubj': 'CSE101',
    'selectChangeYn': 'N',
    'isDefault': true,
    'subjectName': '자료구조 - 김교수',
  },
  {
    'selectYearhakgi': '20261',
    'selectSubj': 'CSE102',
    'selectChangeYn': 'N',
    'isDefault': false,
    'subjectName': '운영체제 - 이교수',
  },
];

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

final class _RestoringSessionManager implements AuthSessionManager {
  _RestoringSessionManager.missingRuntime({required this.durableCredentials});

  _RestoringSessionManager.staleRuntime({required this.durableCredentials})
    : runtimeMetadata = _freshRuntimeMetadata(),
      runtimeMetadataStale = true;

  SessionCredentials? durableCredentials;
  AuthSessionMetadata? runtimeMetadata;
  bool runtimeMetadataStale = false;
  int restoreCount = 0;

  @override
  Future<void> clear() async {
    durableCredentials = null;
    runtimeMetadata = null;
    runtimeMetadataStale = false;
  }

  @override
  Future<bool> hasSession() async => durableCredentials != null;

  @override
  Future<SessionCredentials?> load() async {
    if (durableCredentials == null) {
      return null;
    }
    if (runtimeMetadata == null || runtimeMetadataStale) {
      restoreCount++;
      runtimeMetadata = _freshRuntimeMetadata();
      runtimeMetadataStale = false;
    }
    return durableCredentials;
  }

  @override
  Future<void> save(SessionCredentials newCredentials) async {
    durableCredentials = newCredentials;
    runtimeMetadata = _freshRuntimeMetadata();
    runtimeMetadataStale = false;
  }
}

AuthSessionMetadata _freshRuntimeMetadata() {
  return const AuthSessionMetadata(
    schemaVersion: '1.0',
    port: 4321,
    token: '0123456789abcdef0123456789abcdef0123456789',
    pid: 12345,
    createdAt: '2026-03-20T12:00:00.000Z',
  );
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

http.Response _jsonAnyResponse(Object body, {int statusCode = 200}) {
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
