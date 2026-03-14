import 'dart:convert';
import 'dart:async';

import 'package:klas_cli/klas_cli.dart';
import 'package:klas_cli/src/auth/terminal.dart';
import 'package:klas_cli/src/errors/cli_errors.dart';
import 'package:klas_cli/src/models/cli_models.dart';
import 'package:klas_cli/src/services/klas_service.dart';
import 'package:test/test.dart';

void main() {
  test('courses list prints stable JSON envelope', () async {
    final terminal = FakeTerminal();
    final service = FakeKlasService(
      listCoursesHandler: ({required allowPrompt}) async =>
          CommandPayload<List<CourseView>>(
            data: const <CourseView>[
              CourseView(
                courseId: 'CSE101',
                termId: '20261',
                title: 'Data Structures',
                professorName: 'Kim',
                isDefault: true,
              ),
            ],
            meta: const <String, Object?>{'count': 1},
          ),
    );

    final exitCode = await runKlasCli(
      <String>['--format', 'json', 'courses', 'list'],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.success);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(payload['ok'], isTrue);
    expect(payload['command'], 'courses list');
    expect(payload['meta']['count'], 1);
    expect(payload['data'][0]['course_id'], 'CSE101');
  });

  test('profile auth failure prints structured JSON error', () async {
    final terminal = FakeTerminal();
    final service = FakeKlasService(
      profileHandler: ({required allowPrompt}) async =>
          throw const CliException(
            code: 'AUTH_REQUIRED',
            message: 'Authentication is required for this command.',
            exitCode: ExitCodes.auth,
          ),
    );

    final exitCode = await runKlasCli(
      <String>['--format', 'json', 'me', 'profile'],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.auth);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(payload['ok'], isFalse);
    expect(payload['command'], 'me profile');
    expect(payload['error']['code'], 'AUTH_REQUIRED');
  });

  test('tasks show validates integer task number', () async {
    final terminal = FakeTerminal();
    final service = FakeKlasService();

    final exitCode = await runKlasCli(
      <String>['--format', 'json', 'tasks', 'show', 'abc'],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.usage);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(payload['error']['code'], 'USAGE_ERROR');
  });

  test('courses show requires --course before service execution', () async {
    final terminal = FakeTerminal();
    var called = false;
    final service = FakeKlasService(
      showCourseHandler: (selector, {required allowPrompt}) async {
        called = true;
        return CommandPayload<CourseView>(
          data: CourseView(
            courseId: selector,
            termId: '20261',
            isDefault: false,
          ),
        );
      },
    );

    final exitCode = await runKlasCli(
      <String>['--format', 'json', 'courses', 'show'],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.usage);
    expect(called, isFalse);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(payload['error']['code'], 'USAGE_ERROR');
    expect(
      payload['error']['message'],
      contains('Missing required option: --course'),
    );
  });

  test('tasks show help includes required positional argument', () async {
    final terminal = FakeTerminal();

    final output = await capturePrints(() async {
      final exitCode = await runKlasCli(
        <String>['help', 'tasks', 'show'],
        terminal: terminal,
        service: FakeKlasService(),
      );

      expect(exitCode, ExitCodes.success);
    });

    expect(output, contains('Usage: klas tasks show <task_no> [arguments]'));
  });

  test('schema command returns machine-readable command contract', () async {
    final terminal = FakeTerminal();

    final exitCode = await runKlasCli(
      <String>['--format', 'json', 'schema', 'tasks', 'list'],
      terminal: terminal,
      service: FakeKlasService(),
    );

    expect(exitCode, ExitCodes.success);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(payload['ok'], isTrue);
    expect(payload['data']['path'], 'tasks list');
    expect(payload['data']['supports_dry_run'], isTrue);
  });

  test('schema timetable lists week subcommand', () async {
    final terminal = FakeTerminal();

    final exitCode = await runKlasCli(
      <String>['--format', 'json', 'schema', 'timetable'],
      terminal: terminal,
      service: FakeKlasService(),
    );

    expect(exitCode, ExitCodes.success);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(payload['data']['subcommands'], <dynamic>['timetable week']);
  });

  test('schema calendar lists month subcommand', () async {
    final terminal = FakeTerminal();

    final exitCode = await runKlasCli(
      <String>['--format', 'json', 'schema', 'calendar'],
      terminal: terminal,
      service: FakeKlasService(),
    );

    expect(exitCode, ExitCodes.success);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(payload['data']['subcommands'], <dynamic>['calendar month']);
  });

  test('schema schedule path is removed from the canonical surface', () async {
    final terminal = FakeTerminal();

    final exitCode = await runKlasCli(
      <String>['--format', 'json', 'schema', 'schedule'],
      terminal: terminal,
      service: FakeKlasService(),
    );

    expect(exitCode, ExitCodes.usage);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(payload['error']['code'], 'USAGE_ERROR');
    expect(
      payload['error']['message'],
      contains('No schema entry matched the requested command path'),
    );
  });

  test(
    'calendar month validates month range before service execution',
    () async {
      final terminal = FakeTerminal();
      var called = false;
      final service = FakeKlasService(
        scheduleMonthHandler: ({required allowPrompt, year, month}) async {
          called = true;
          return const CommandPayload<List<ScheduleView>>(
            data: <ScheduleView>[],
          );
        },
      );

      final exitCode = await runKlasCli(
        <String>['--format', 'json', 'calendar', 'month', '--month', '13'],
        terminal: terminal,
        service: service,
      );

      expect(exitCode, ExitCodes.usage);
      expect(called, isFalse);
      final payload =
          jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
      expect(payload['error']['code'], 'USAGE_ERROR');
      expect(
        payload['error']['message'],
        contains('month must be between 1 and 12'),
      );
    },
  );

  test('calendar month forwards validated year and month to service', () async {
    final terminal = FakeTerminal();
    int? seenYear;
    int? seenMonth;
    final service = FakeKlasService(
      scheduleMonthHandler: ({required allowPrompt, year, month}) async {
        seenYear = year;
        seenMonth = month;
        return const CommandPayload<List<ScheduleView>>(data: <ScheduleView>[]);
      },
    );

    final exitCode = await runKlasCli(
      <String>[
        '--format',
        'json',
        'calendar',
        'month',
        '--year',
        '2026',
        '--month',
        '3',
      ],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.success);
    expect(seenYear, 2026);
    expect(seenMonth, 3);
  });

  test('timetable week forwards to timetable service path', () async {
    final terminal = FakeTerminal();
    var called = false;
    final service = FakeKlasService(
      scheduleWeekHandler: ({required allowPrompt}) async {
        called = true;
        return const CommandPayload<List<ScheduleView>>(data: <ScheduleView>[]);
      },
    );

    final exitCode = await runKlasCli(
      <String>['--format', 'json', 'timetable', 'week'],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.success);
    expect(called, isTrue);
  });

  test('fields trims json data to the requested keys', () async {
    final terminal = FakeTerminal();
    final service = FakeKlasService(
      listCoursesHandler: ({required allowPrompt}) async =>
          CommandPayload<List<CourseView>>(
            data: const <CourseView>[
              CourseView(
                courseId: 'CSE101',
                termId: '20261',
                title: 'Data Structures',
                professorName: 'Kim',
                isDefault: true,
              ),
            ],
          ),
    );

    final exitCode = await runKlasCli(
      <String>[
        '--format',
        'json',
        '--fields',
        'course_id,title',
        'courses',
        'list',
      ],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.success);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(
      payload['data'][0].keys,
      unorderedEquals(<String>['course_id', 'title']),
    );
    expect(payload['meta']['fields'], <dynamic>['course_id', 'title']);
  });

  test('dry-run validates without calling the service', () async {
    final terminal = FakeTerminal();
    var called = false;
    final service = FakeKlasService(
      listCoursesHandler: ({required allowPrompt}) async {
        called = true;
        return const CommandPayload<List<CourseView>>(data: <CourseView>[]);
      },
    );

    final exitCode = await runKlasCli(
      <String>['--format', 'json', '--dry-run', 'courses', 'list'],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.success);
    expect(called, isFalse);
    final payload =
        jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
    expect(payload['data']['validated'], isTrue);
    expect(payload['meta']['dry_run'], isTrue);
    expect(payload['meta']['network_call'], isFalse);
  });

  test(
    'course selector rejects query fragments before service execution',
    () async {
      final terminal = FakeTerminal();
      var called = false;
      final service = FakeKlasService(
        listTasksHandler:
            ({required allowPrompt, String? courseSelector}) async {
              called = true;
              return const CommandPayload<List<TaskView>>(data: <TaskView>[]);
            },
      );

      final exitCode = await runKlasCli(
        <String>[
          '--format',
          'json',
          'tasks',
          'list',
          '--course',
          'CSE101?fields=name',
        ],
        terminal: terminal,
        service: service,
      );

      expect(exitCode, ExitCodes.usage);
      expect(called, isFalse);
      final payload =
          jsonDecode(terminal.outLines.single) as Map<String, dynamic>;
      expect(payload['error']['code'], 'USAGE_ERROR');
    },
  );

  test('auth status text output stays human-readable', () async {
    final terminal = FakeTerminal();
    final service = FakeKlasService(
      authStatusHandler: () async => CommandPayload<AuthStatusView>(
        data: AuthStatusView(
          authenticated: false,
          reusable: false,
          credentialSource: 'none',
          checkedAt: '2026-03-09T00:00:00',
          interactiveAvailable: false,
          hint: 'Configure environment variables.',
        ),
      ),
    );

    final exitCode = await runKlasCli(
      <String>['auth', 'status'],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.success);
    expect(terminal.outLines.single, contains('Authenticated: no'));
    expect(
      terminal.outLines.single,
      contains('Hint: Configure environment variables.'),
    );
  });

  test('auth login forwards stdin-json flag to service', () async {
    final terminal = FakeTerminal();
    var usedStdinJson = false;
    final service = FakeKlasService(
      loginHandler: ({required allowPrompt, required useStdinJson}) async {
        usedStdinJson = useStdinJson;
        return const CommandPayload<AuthLoginView>(
          data: AuthLoginView(
            authenticated: true,
            credentialSource: 'stdin_json',
            reusable: true,
            checkedAt: '2026-03-09T00:00:00',
          ),
        );
      },
    );

    final exitCode = await runKlasCli(
      <String>['auth', 'login', '--stdin-json'],
      terminal: terminal,
      service: service,
    );

    expect(exitCode, ExitCodes.success);
    expect(usedStdinJson, isTrue);
  });
}

final class FakeTerminal implements Terminal {
  @override
  bool get canPrompt => false;

  final List<String> outLines = <String>[];
  final List<String> errLines = <String>[];

  @override
  Future<String?> prompt(String message, {bool secret = false}) async => null;

  @override
  void writeErr(String message) {
    errLines.add(message);
  }

  @override
  void writeOut(String message) {
    outLines.add(message);
  }
}

Future<String> capturePrints(Future<void> Function() action) async {
  final buffer = StringBuffer();

  await runZoned(
    () async {
      await action();
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        buffer.writeln(line);
      },
    ),
  );

  return buffer.toString();
}

typedef LoginHandler =
    Future<CommandPayload<AuthLoginView>> Function({
      required bool allowPrompt,
      required bool useStdinJson,
    });
typedef ProfileHandler =
    Future<CommandPayload<ProfileView>> Function({required bool allowPrompt});
typedef ListCoursesHandler =
    Future<CommandPayload<List<CourseView>>> Function({
      required bool allowPrompt,
    });
typedef ShowCourseHandler =
    Future<CommandPayload<CourseView>> Function(
      String selector, {
      required bool allowPrompt,
    });
typedef AuthStatusHandler = Future<CommandPayload<AuthStatusView>> Function();
typedef ListTasksHandler =
    Future<CommandPayload<List<TaskView>>> Function({
      required bool allowPrompt,
      String? courseSelector,
    });
typedef ScheduleMonthHandler =
    Future<CommandPayload<List<ScheduleView>>> Function({
      required bool allowPrompt,
      int? year,
      int? month,
    });
typedef ScheduleWeekHandler =
    Future<CommandPayload<List<ScheduleView>>> Function({
      required bool allowPrompt,
    });

final class FakeKlasService implements KlasService {
  FakeKlasService({
    this.loginHandler,
    this.authStatusHandler,
    this.profileHandler,
    this.listCoursesHandler,
    this.showCourseHandler,
    this.listTasksHandler,
    this.scheduleMonthHandler,
    this.scheduleWeekHandler,
  });

  final LoginHandler? loginHandler;
  final AuthStatusHandler? authStatusHandler;
  final ProfileHandler? profileHandler;
  final ListCoursesHandler? listCoursesHandler;
  final ShowCourseHandler? showCourseHandler;
  final ListTasksHandler? listTasksHandler;
  final ScheduleMonthHandler? scheduleMonthHandler;
  final ScheduleWeekHandler? scheduleWeekHandler;

  @override
  Future<CommandPayload<AuthStatusView>> authStatus() async {
    return authStatusHandler?.call() ??
        CommandPayload<AuthStatusView>(
          data: AuthStatusView(
            authenticated: false,
            reusable: false,
            credentialSource: 'none',
            checkedAt: '2026-03-09T00:00:00',
          ),
        );
  }

  @override
  Future<CommandPayload<List<CourseView>>> listCourses({
    required bool allowPrompt,
  }) async {
    return listCoursesHandler?.call(allowPrompt: allowPrompt) ??
        const CommandPayload<List<CourseView>>(data: <CourseView>[]);
  }

  @override
  Future<CommandPayload<AuthLoginView>> login({
    required bool allowPrompt,
    required bool useStdinJson,
  }) async {
    return loginHandler?.call(
          allowPrompt: allowPrompt,
          useStdinJson: useStdinJson,
        ) ??
        const CommandPayload<AuthLoginView>(
          data: AuthLoginView(
            authenticated: true,
            credentialSource: 'env',
            reusable: true,
            checkedAt: '2026-03-09T00:00:00',
          ),
        );
  }

  @override
  Future<CommandPayload<ProfileView>> profile({
    required bool allowPrompt,
  }) async {
    return profileHandler?.call(allowPrompt: allowPrompt) ??
        const CommandPayload<ProfileView>(
          data: ProfileView(authenticated: true, name: 'Tester'),
        );
  }

  @override
  Future<CommandPayload<SimpleMessageView>> logout() async {
    return const CommandPayload<SimpleMessageView>(
      data: SimpleMessageView(message: 'ok'),
    );
  }

  @override
  Future<CommandPayload<List<TaskView>>> listTasks({
    required bool allowPrompt,
    String? courseSelector,
  }) async {
    return listTasksHandler?.call(
          allowPrompt: allowPrompt,
          courseSelector: courseSelector,
        ) ??
        const CommandPayload<List<TaskView>>(data: <TaskView>[]);
  }

  @override
  Future<CommandPayload<List<NoticeView>>> listNotices({
    required bool allowPrompt,
    String? courseSelector,
  }) async {
    return const CommandPayload<List<NoticeView>>(data: <NoticeView>[]);
  }

  @override
  Future<CommandPayload<List<ScheduleView>>> scheduleMonth({
    required bool allowPrompt,
    int? year,
    int? month,
  }) async {
    return scheduleMonthHandler?.call(
          allowPrompt: allowPrompt,
          year: year,
          month: month,
        ) ??
        const CommandPayload<List<ScheduleView>>(data: <ScheduleView>[]);
  }

  @override
  Future<CommandPayload<List<ScheduleView>>> scheduleWeek({
    required bool allowPrompt,
  }) async {
    return scheduleWeekHandler?.call(allowPrompt: allowPrompt) ??
        const CommandPayload<List<ScheduleView>>(data: <ScheduleView>[]);
  }

  @override
  Future<CommandPayload<CourseView>> showCourse(
    String selector, {
    required bool allowPrompt,
  }) async {
    return showCourseHandler?.call(selector, allowPrompt: allowPrompt) ??
        CommandPayload<CourseView>(
          data: CourseView(
            courseId: selector,
            termId: '20261',
            isDefault: false,
          ),
        );
  }

  @override
  Future<CommandPayload<TaskView>> showTask(
    int taskNo, {
    required bool allowPrompt,
    String? courseSelector,
  }) async {
    return CommandPayload<TaskView>(
      data: TaskView(
        courseId: courseSelector ?? 'CSE101',
        courseTitle: 'Data Structures',
        taskNo: taskNo,
        submissionStatus: TaskSubmissionStatus.unknown,
      ),
    );
  }
}
