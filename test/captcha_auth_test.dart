import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klas_cli/klas_cli.dart';
import 'package:klas_cli/src/auth/captcha_prompter.dart';
import 'package:klas_cli/src/auth/session_manager.dart';
import 'package:klas_cli/src/auth/session_metadata.dart';
import 'package:klas_cli/src/auth/terminal.dart';
import 'package:klas_cli/src/errors/cli_errors.dart';
import 'package:klas_cli/src/services/klas_service.dart';
import 'package:klasflow/klasflow.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryRoot;
  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp('klas-captcha-test-');
  });
  tearDown(() async => temporaryRoot.delete(recursive: true));

  test(
    'prompt preserves leading zeros and cleans up the opened image',
    () async {
      final terminal = _Terminal(answers: ['abc', ' 0012 ']);
      String? openedPath;
      final prompter = CaptchaPrompter(
        terminal: terminal,
        temporaryRoot: temporaryRoot,
        imageOpener: (path) async {
          openedPath = path;
          expect(await File(path).readAsBytes(), [1, 2, 3]);
          expect(path, endsWith('.jpg'));
        },
      );
      expect(await prompter.answer(_challenge), '0012');
      expect(terminal.prompts, hasLength(2));
      expect(terminal.err.join(), contains('Enter only the digits'));
      expect(terminal.out, isEmpty);
      expect(await File(openedPath!).exists(), isFalse);
      expect(await temporaryRoot.list().toList(), isEmpty);
    },
  );

  test(
    'unavailable image viewer allows manual opening and cancellation',
    () async {
      final terminal = _Terminal(answers: ['']);
      final prompter = CaptchaPrompter(
        terminal: terminal,
        temporaryRoot: temporaryRoot,
        imageOpener: (_) async => throw StateError('Viewer unavailable'),
      );
      expect(await prompter.answer(_challenge), isNull);
      expect(terminal.err.join(), contains('Open the captcha image path'));
      expect(terminal.out, isEmpty);
      expect(await temporaryRoot.list().toList(), isEmpty);
    },
  );

  test('image is removed when terminal input fails', () async {
    final prompter = CaptchaPrompter(
      terminal: _Terminal(promptError: StateError('Input unavailable')),
      temporaryRoot: temporaryRoot,
      imageOpener: (_) async {},
    );
    await expectLater(prompter.answer(_challenge), throwsStateError);
    expect(await temporaryRoot.list().toList(), isEmpty);
  });

  test(
    'interactive auth login continues captcha and only then saves auth',
    () async {
      final terminal = _Terminal(answers: ['0042']);
      final fixture = _Fixture(terminal, temporaryRoot);
      fixture.onOpen = () {
        expect(fixture.session.saveCount, 0);
      };
      final exit = await runKlasCli(
        ['auth', 'login'],
        terminal: terminal,
        service: fixture.service,
      );
      expect(exit, ExitCodes.success);
      expect(fixture.submitted, ['0042']);
      expect(fixture.images, 1);
      expect(fixture.session.saveCount, 1);
      expect(fixture.session.credentials, isNotNull);
      expect(terminal.err.join(), contains('numeric captcha (1/3)'));
      expect(terminal.out.join(), isNot(contains('captcha-test-')));
      expect(await temporaryRoot.list().toList(), isEmpty);
    },
  );

  test(
    'normal text commands continue captcha with stored credentials',
    () async {
      final terminal = _Terminal(answers: ['0042']);
      final fixture = _Fixture(terminal, temporaryRoot, environment: false);
      final exit = await runKlasCli(
        ['courses', 'list'],
        terminal: terminal,
        service: fixture.service,
      );
      expect(exit, ExitCodes.success);
      expect(fixture.submitted, ['0042']);
      expect(fixture.session.clearCount, 0);
      expect(terminal.out.join(), contains('CSE101'));
    },
  );

  for (final command in [
    ['auth', 'login'],
    ['courses', 'list'],
    ['auth', 'status'],
  ]) {
    test(
      'JSON ${command.join(' ')} reports captcha without input or clearing auth',
      () async {
        final terminal = _Terminal();
        final fixture = _Fixture(terminal, temporaryRoot);
        final exit = await runKlasCli(
          ['--format', 'json', ...command],
          terminal: terminal,
          service: fixture.service,
        );
        expect(exit, ExitCodes.auth);
        final json = jsonDecode(terminal.out.single) as Map<String, dynamic>;
        expect(json['ok'], isFalse);
        expect(json['error']['code'], 'AUTH_CAPTCHA_REQUIRED');
        expect(json['error']['hint'], contains('interactive terminal'));
        expect(terminal.prompts, isEmpty);
        expect(terminal.err, isEmpty);
        expect(fixture.images, 0);
        expect(fixture.submitted, isEmpty);
        expect(fixture.session.clearCount, 0);
        expect(fixture.session.credentials, isNotNull);
      },
    );
  }

  test('noninteractive text login does not open images or prompt', () async {
    final terminal = _Terminal(canPrompt: false);
    final fixture = _Fixture(terminal, temporaryRoot);
    final exit = await runKlasCli(
      ['auth', 'login'],
      terminal: terminal,
      service: fixture.service,
    );
    expect(exit, ExitCodes.auth);
    expect(terminal.err.join(), contains('captcha challenge'));
    expect(terminal.prompts, isEmpty);
    expect(fixture.images, 0);
    expect(fixture.session.saveCount, 0);
  });

  for (final answers in <List<String?>>[
    [''],
    [null],
    ['1', '2', '3'],
  ]) {
    test(
      'cancelled or exhausted captcha preserves existing auth ($answers)',
      () async {
        final terminal = _Terminal(answers: answers);
        final fixture = _Fixture(terminal, temporaryRoot, environment: false);
        final exit = await runKlasCli(
          ['courses', 'list'],
          terminal: terminal,
          service: fixture.service,
        );
        expect(exit, ExitCodes.auth);
        expect(terminal.err.join(), contains('captcha challenge'));
        expect(fixture.session.clearCount, 0);
        expect(fixture.session.credentials, isNotNull);
        expect(fixture.session.saveCount, 0);
        expect(fixture.images, answers.length);
        expect(await temporaryRoot.list().toList(), isEmpty);
      },
    );
  }
}

final _challenge = KlasCaptchaChallenge(
  image: FilePayload(
    bytes: Uint8List.fromList([1, 2, 3]),
    contentType: 'image/jpeg; charset=binary',
  ),
  attempt: 1,
  maxAttempts: 3,
);

final class _Fixture {
  _Fixture(this.terminal, Directory temporaryRoot, {bool environment = true}) {
    service = KlasflowService(
      terminal: terminal,
      sessionManager: session,
      environment: environment
          ? {'KLAS_ID': 'test-user', 'KLAS_PASSWORD': 'test-password'}
          : {},
      captchaPrompter: CaptchaPrompter(
        terminal: terminal,
        temporaryRoot: temporaryRoot,
        imageOpener: (path) async {
          expect(await File(path).exists(), isTrue);
          onOpen?.call();
        },
      ),
      clientFactory: () => KlasClient(
        config: KlasClientConfig(baseUri: Uri.parse('https://example.com')),
        httpClient: MockClient((request) async {
          switch (request.url.path) {
            case '/usr/cmn/login/LoginSecurity.do':
              return _json({
                'data': {
                  'publicKeyModulus': _modulus,
                  'publicKeyExponent': '10001',
                  'loginToken': 'fixture-nonce',
                },
              });
            case '/usr/cmn/login/LoginCaptcha.do':
              return _json(3);
            case '/usr/cmn/login/captchaImg.do':
              images++;
              return http.Response.bytes(
                [1, 2, images],
                200,
                headers: {
                  'content-type': 'image/png',
                  'set-cookie': 'challenge=fixture; Path=/',
                },
              );
            case '/usr/cmn/login/LoginConfirm.do':
              final answer = request.bodyFields['captcha'];
              expect(request.headers['cookie'], contains('challenge=fixture'));
              submitted.add(answer!);
              return _json(
                answer == '0042'
                    ? {'errorCount': 0}
                    : {'errorCount': 3, 'captchaRequired': true},
              );
            case '/std/cmn/frame/KlasStop.do':
              return http.Response('<html>KLAS</html>', 200);
            case '/std/cmn/frame/YearhakgiAtnlcSbjectList.do':
              return _json({
                'data': [
                  {
                    'selectYearhakgi': '20261',
                    'selectSubj': 'CSE101',
                    'selectChangeYn': 'N',
                    'isDefault': true,
                    'subjectName': 'Test Course',
                  },
                ],
              });
            case '/api/v1/session/info':
              return _json({
                'authenticated': true,
                'userId': 'test-user',
                'userName': 'Tester',
              });
            default:
              return http.Response('Not Found', 404);
          }
        }),
      ),
    );
  }
  final _Terminal terminal;
  final session = _Session();
  late final KlasflowService service;
  int images = 0;
  final submitted = <String>[];
  void Function()? onOpen;
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
const _modulus =
    'd3b0a5d2e6f8c1b4998e77aa31bc4d2f3a7cb9e1ffacde099812f3aa1c8d9e07'
    '84a79b7654f0cc22a1346d8eaf3b70c9d11be9ee02baf7a90876efbda12340fd'
    'c7a8f9d01234abcdeffedcba98765432100112233445566778899aabbccddeeff';

final class _Terminal implements Terminal {
  _Terminal({this.canPrompt = true, List<String?>? answers, this.promptError})
    : answers = [...?answers];
  @override
  final bool canPrompt;
  final List<String?> answers;
  final Object? promptError;
  final out = <String>[];
  final err = <String>[];
  final prompts = <String>[];
  @override
  Future<String?> prompt(String message, {bool secret = false}) async {
    prompts.add(message);
    if (promptError != null) throw promptError!;
    return answers.isEmpty ? null : answers.removeAt(0);
  }

  @override
  void writeErr(String message) => err.add(message);
  @override
  void writeOut(String message) => out.add(message);
}

final class _Session implements AuthSessionManager {
  SessionCredentials? credentials = const SessionCredentials(
    id: 'test-user',
    password: 'test-password',
  );
  int clearCount = 0;
  int saveCount = 0;
  @override
  Future<void> clear() async {
    clearCount++;
    credentials = null;
  }

  @override
  Future<bool> hasSession() async => credentials != null;
  @override
  Future<SessionCredentials?> load() async => credentials;
  @override
  Future<void> save(SessionCredentials value) async {
    saveCount++;
    credentials = value;
  }
}
