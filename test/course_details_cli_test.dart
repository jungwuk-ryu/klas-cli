import 'dart:convert';
import 'dart:io';

import 'package:klas_cli/klas_cli.dart';
import 'package:klas_cli/src/commands/command_schema.dart';
import 'package:klas_cli/src/errors/cli_errors.dart';
import 'package:klas_cli/src/models/cli_models.dart';
import 'package:klas_cli/src/output/body_text.dart';
import 'package:test/test.dart';

import 'cli_test.dart' show FakeTerminal, FakeKlasService, capturePrints;

const _notice = NoticeView(
  courseId: 'CSE101',
  courseTitle: '자료구조',
  boardNo: 7,
  title: '시험 안내',
  authorName: '김교수',
  hasAttachments: true,
  fileCount: 1,
  contentHtml: '<p>강의실 변경 &amp; 준비물</p>',
  contentText: '강의실 변경 & 준비물',
  attachments: [AttachmentView(fileName: '안내.pdf', sizeBytes: 123)],
);
const _task = TaskView(
  courseId: 'CSE101',
  courseTitle: '자료구조',
  taskNo: 12,
  submissionStatus: TaskSubmissionStatus.submitted,
  reportTitle: '과제 안내',
  reportHtml: '<p>코드를 작성하세요.</p>',
  reportText: '코드를 작성하세요.',
  submissionText: '완료했습니다.',
  attachments: [AttachmentView(fileName: '문제.pdf', sizeBytes: 5)],
  submissionAttachments: [
    AttachmentView(fileName: '답안.zip', localPath: '/tmp/답안.zip'),
  ],
);

void main() {
  test('body text preserves paragraphs, breaks, lists, entities and links', () {
    expect(
      bodyText('<p>첫째 &amp; 둘째<br>새 줄</p><ul><li>항목 1</li><li>항목 2</li></ul>'),
      allOf(contains('첫째 & 둘째\n새 줄'), contains('- 항목 1'), contains('- 항목 2')),
    );
    expect(
      bodyText('<p><a href="https://example.com">참고</a></p>'),
      '참고 (https://example.com)',
    );
    expect(
      bodyText('<script>secret()</script><style>css</style><p>본문\u001b</p>'),
      '본문',
    );
    expect(bodyText(null), isNull);
    expect(bodyText(''), isEmpty);
    expect(bodyText('태그 없는 본문'), '태그 없는 본문');
    expect(bodyText('첫 줄\n둘째 줄'), '첫 줄\n둘째 줄');
    expect(
      bodyText('<pre>def f():\n    return 1</pre>'),
      'def f():\n    return 1',
    );
  });

  test(
    'notice JSON routes exact course, board number and download directory',
    () async {
      final terminal = FakeTerminal();
      final service = FakeKlasService(
        showNoticeHandler:
            (
              number, {
              required allowPrompt,
              required courseSelector,
              downloadDirectory,
            }) async {
              expect(number, 7);
              expect(allowPrompt, isFalse);
              expect(courseSelector, 'CSE101');
              expect(downloadDirectory, './downloads');
              return const CommandPayload(
                data: _notice,
                warnings: ['Attachment warning'],
              );
            },
      );
      final code = await runKlasCli(
        [
          '--format',
          'json',
          'notices',
          'show',
          '7',
          '--course',
          'CSE101',
          '--download-dir',
          './downloads',
        ],
        terminal: terminal,
        service: service,
      );
      final output = jsonDecode(terminal.outLines.single);
      expect(code, 0);
      expect(output['command'], 'notices show');
      expect(output['data'], _notice.toJson());
      expect(output['warnings'], ['Attachment warning']);
      expect(terminal.errLines, isEmpty);
    },
  );

  test('notice text shows the body and file metadata', () async {
    final terminal = FakeTerminal();
    final code = await runKlasCli(
      ['notices', 'show', '7', '--course', 'CSE101'],
      terminal: terminal,
      service: FakeKlasService(
        showNoticeHandler:
            (
              number, {
              required allowPrompt,
              required courseSelector,
              downloadDirectory,
            }) async => const CommandPayload(data: _notice),
      ),
    );
    expect(code, 0);
    expect(
      terminal.outLines.single,
      allOf(
        contains('자료구조 [CSE101]'),
        contains('강의실 변경 & 준비물'),
        contains('안내.pdf'),
        contains('bytes=123'),
      ),
    );
  });

  test(
    'task text includes instructor body and both attachment groups',
    () async {
      final terminal = FakeTerminal();
      final code = await runKlasCli(
        [
          'tasks',
          'show',
          '12',
          '--course',
          'CSE101',
          '--download-dir',
          './files',
        ],
        terminal: terminal,
        service: FakeKlasService(
          showTaskHandler:
              (
                number, {
                required allowPrompt,
                courseSelector,
                downloadDirectory,
              }) async {
                expect(number, 12);
                expect(courseSelector, 'CSE101');
                expect(downloadDirectory, './files');
                return const CommandPayload(data: _task);
              },
        ),
      );
      expect(code, 0);
      expect(
        terminal.outLines.single,
        allOf(
          contains('코드를 작성하세요.'),
          contains('문제.pdf'),
          contains('Submission attachments:'),
          contains('saved=/tmp/답안.zip'),
        ),
      );
    },
  );

  test(
    'task JSON fields preserves nested attachments and existing HTML',
    () async {
      final terminal = FakeTerminal();
      final code = await runKlasCli(
        [
          '--format',
          'json',
          '--fields',
          'report_html,report_text,attachments,submission_attachments',
          'tasks',
          'show',
          '12',
        ],
        terminal: terminal,
        service: FakeKlasService(
          showTaskHandler:
              (
                number, {
                required allowPrompt,
                courseSelector,
                downloadDirectory,
              }) async => const CommandPayload(data: _task),
        ),
      );
      final output = jsonDecode(terminal.outLines.single);
      expect(code, 0);
      expect(
        output['data'].keys,
        unorderedEquals([
          'report_html',
          'report_text',
          'attachments',
          'submission_attachments',
        ]),
      );
      expect(output['data']['report_html'], _task.reportHtml);
      expect(output['data']['attachments'][0]['file_name'], '문제.pdf');
      expect(
        output['data']['submission_attachments'][0]['local_path'],
        '/tmp/답안.zip',
      );
    },
  );

  test('detail schemas enumerate model fields and download flags', () {
    for (final pair in [
      (contractForPath('tasks show'), _task.toJson()),
      (contractForPath('notices show'), _notice.toJson()),
    ]) {
      expect(pair.$1.outputFields, unorderedEquals(pair.$2.keys));
      expect(
        pair.$1.options.map((option) => option.name),
        contains('--download-dir'),
      );
      expect(pair.$1.supportsDryRun, isTrue);
      expect(pair.$1.warningsPossible, isTrue);
    }
    expect(
      contractForPath(
        'notices show',
      ).options.singleWhere((o) => o.name == '--course').required,
      isTrue,
    );
  });

  test(
    'detail help includes positional number, course and download option',
    () async {
      for (final group in ['tasks', 'notices']) {
        final text = await capturePrints(() async {
          expect(
            await runKlasCli(
              ['help', group, 'show'],
              terminal: FakeTerminal(),
              service: FakeKlasService(),
            ),
            0,
          );
        });
        expect(
          text,
          allOf(
            contains('Usage: klas $group show <'),
            contains('--course'),
            contains('--download-dir'),
          ),
        );
      }
    },
  );

  test('notice list includes course id for follow-up detail', () async {
    final terminal = FakeTerminal();
    expect(
      await runKlasCli(
        ['notices', 'list'],
        terminal: terminal,
        service: FakeKlasService(
          listNoticesHandler: ({required allowPrompt, courseSelector}) async =>
              const CommandPayload(data: [_notice]),
        ),
      ),
      0,
    );
    expect(terminal.outLines.single, contains('[자료구조 | CSE101] #7'));
  });

  test('invalid details are rejected before calling the service', () async {
    var called = false;
    final service = FakeKlasService(
      showNoticeHandler:
          (
            number, {
            required allowPrompt,
            required courseSelector,
            downloadDirectory,
          }) async {
            called = true;
            return const CommandPayload(data: _notice);
          },
      showTaskHandler:
          (
            number, {
            required allowPrompt,
            courseSelector,
            downloadDirectory,
          }) async {
            called = true;
            return const CommandPayload(data: _task);
          },
    );
    final cases = [
      ['notices', 'show', '7'],
      ['notices', 'show', '--course', 'CSE101'],
      ['notices', 'show', 'bad', '--course', 'CSE101'],
      ['notices', 'show', '7', '8', '--course', 'CSE101'],
      ['notices', 'show', '7', '--course', 'CSE101?x'],
      ['notices', 'show', '7', '--course', '', '--download-dir', './files'],
      ['notices', 'show', '7', '--course', 'CSE101', '--download-dir', ''],
      ['tasks', 'show', '12', '--download-dir', 'bad\npath'],
      ['tasks', 'show', '--', '-1'],
    ];
    for (final arguments in cases) {
      final terminal = FakeTerminal();
      expect(
        await runKlasCli(
          ['--format', 'json', ...arguments],
          terminal: terminal,
          service: service,
        ),
        ExitCodes.usage,
      );
      expect(
        jsonDecode(terminal.outLines.single)['error']['code'],
        'USAGE_ERROR',
      );
    }
    expect(called, isFalse);
  });

  test(
    'detail dry-run neither calls the service nor creates a directory',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'klas-detail-dry-run-',
      );
      addTearDown(() => root.delete(recursive: true));
      final destination = '${root.path}/uncreated';
      final service = FakeKlasService(
        showNoticeHandler:
            (
              number, {
              required allowPrompt,
              required courseSelector,
              downloadDirectory,
            }) async => throw StateError('must not call service'),
        showTaskHandler:
            (
              number, {
              required allowPrompt,
              courseSelector,
              downloadDirectory,
            }) async => throw StateError('must not call service'),
      );
      for (final group in ['tasks', 'notices']) {
        final terminal = FakeTerminal();
        expect(
          await runKlasCli(
            [
              '--format',
              'json',
              '--dry-run',
              group,
              'show',
              '7',
              '--course',
              'CSE101',
              '--download-dir',
              destination,
            ],
            terminal: terminal,
            service: service,
          ),
          0,
        );
        expect(
          jsonDecode(terminal.outLines.single)['meta']['network_call'],
          isFalse,
        );
      }
      expect(await Directory(destination).exists(), isFalse);
    },
  );

  test('missing notice has structured not-found output', () async {
    final terminal = FakeTerminal();
    final code = await runKlasCli(
      ['--format', 'json', 'notices', 'show', '7', '--course', 'CSE101'],
      terminal: terminal,
      service: FakeKlasService(
        showNoticeHandler:
            (
              number, {
              required allowPrompt,
              required courseSelector,
              downloadDirectory,
            }) async => throw const CliException(
              code: 'NOTICE_NOT_FOUND',
              message: 'Missing notice.',
              exitCode: ExitCodes.notFound,
            ),
      ),
    );
    expect(code, ExitCodes.notFound);
    expect(
      jsonDecode(terminal.outLines.single)['error']['code'],
      'NOTICE_NOT_FOUND',
    );
    expect(terminal.errLines, isEmpty);
  });
}
