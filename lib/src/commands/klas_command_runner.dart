import 'package:args/command_runner.dart';

import 'command_schema.dart';
import '../auth/session_manager.dart';
import '../auth/terminal.dart';
import '../errors/cli_errors.dart';
import '../models/cli_models.dart';
import '../output/cli_output.dart';
import '../services/klas_service.dart';
import '../validation/input_validation.dart';

final class KlasCommandRunner extends CommandRunner<int> {
  KlasCommandRunner({
    required Terminal terminal,
    required KlasService service,
    required AuthSessionManager sessionManager,
  }) : _terminal = terminal,
       _service = service,
       super('klas', 'Agent-first KLAS CLI for students and automation.') {
    argParser.addOption(
      'format',
      help: 'Output format.',
      allowed: const <String>['text', 'json'],
      defaultsTo: 'text',
    );
    argParser.addOption(
      'fields',
      help:
          'Comma-separated top-level JSON data fields to keep in the response.',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Validate local inputs without calling KLAS.',
    );

    addCommand(AuthGroupCommand(_terminal, _service));
    addCommand(MeGroupCommand(_terminal, _service));
    addCommand(CoursesGroupCommand(_terminal, _service));
    addCommand(TasksGroupCommand(_terminal, _service));
    addCommand(NoticesGroupCommand(_terminal, _service));
    addCommand(ScheduleGroupCommand(_terminal, _service));
    addCommand(SchemaCommand(_terminal, _service));
    addCommand(AuthDaemonServeCommand(sessionManager));
  }

  final Terminal _terminal;
  final KlasService _service;

  String describeCommand(List<String> arguments) {
    final parts = <String>[];
    var skipNext = false;
    for (final argument in arguments) {
      if (skipNext) {
        skipNext = false;
        continue;
      }
      if (argument == '--format' || argument == '--fields') {
        skipNext = true;
        continue;
      }
      if (argument.startsWith('--format=') ||
          argument.startsWith('--fields=')) {
        continue;
      }
      if (argument == '--dry-run') {
        continue;
      }
      if (argument.startsWith('-')) {
        continue;
      }
      parts.add(argument);
      if (parts.length == 2) {
        break;
      }
    }
    return parts.isEmpty ? 'help' : parts.join(' ');
  }
}

abstract base class KlasCommand<T> extends Command<int> {
  KlasCommand(this.terminal, this.service);

  final Terminal terminal;
  final KlasService service;

  bool get allowPrompt =>
      terminal.canPrompt && outputFormat == OutputFormat.text;

  OutputFormat get outputFormat =>
      OutputFormatValue.parse(globalResults?['format'] as String?);

  List<String> get selectedFields =>
      parseSelectedFields(globalResults?['fields'] as String?);

  bool get dryRun => globalResults?['dry-run'] as bool? ?? false;

  CommandContract get contract => contractForPath(commandPath);

  CliOutput get output => CliOutput(
    terminal: terminal,
    format: outputFormat,
    selectedFields: selectedFields,
  );

  String get commandPath =>
      [if (parent != null) parent!.name, name].whereType<String>().join(' ');

  Future<CommandPayload<T>> load();

  void validateInputs() {}

  Object? toJson(T value);

  String toText(T value);

  CommandPayload<Object?> buildDryRunPayload() {
    return CommandPayload<Object?>(
      data: <String, Object?>{'validated': true, 'command': commandPath},
      meta: <String, Object?>{
        'dry_run': true,
        'network_call': false,
        'auth_required': contract.authRequired,
      },
    );
  }

  @override
  Future<int> run() async {
    if (selectedFields.isNotEmpty && outputFormat != OutputFormat.json) {
      throw const CliException(
        code: 'USAGE_ERROR',
        message: '`--fields` is only available with `--format json`.',
        exitCode: ExitCodes.usage,
        hint:
            'Run the command with `--format json --fields field_one,field_two`.',
      );
    }

    validateInputs();

    if (dryRun) {
      if (!contract.supportsDryRun) {
        throw const CliException(
          code: 'UNSUPPORTED_FEATURE',
          message: 'This command does not support `--dry-run`.',
          exitCode: ExitCodes.usage,
        );
      }
      output.printSuccess(
        commandPath,
        buildDryRunPayload(),
        toJson: (value) => value,
        toText: (_) => 'Validated local inputs. No KLAS request was sent.',
      );
      return ExitCodes.success;
    }

    final payload = await load();
    output.printSuccess(commandPath, payload, toJson: toJson, toText: toText);
    return ExitCodes.success;
  }
}

final class AuthGroupCommand extends Command<int> {
  AuthGroupCommand(Terminal terminal, KlasService service) {
    addSubcommand(AuthLoginCommand(terminal, service));
    addSubcommand(AuthStatusCommand(terminal, service));
    addSubcommand(AuthLogoutCommand(terminal, service));
  }

  @override
  String get name => 'auth';

  @override
  String get description => 'Authenticate and inspect CLI auth readiness.';
}

final class AuthLoginCommand extends KlasCommand<AuthLoginView> {
  AuthLoginCommand(super.terminal, super.service) {
    argParser.addFlag(
      'stdin-json',
      negatable: false,
      help:
          'Read credentials as JSON from stdin. Expected shape: {"id":"...","password":"..."}.',
    );
  }

  @override
  String get name => 'login';

  @override
  String get description =>
      'Authenticate with KLAS and create durable local reusable auth.';

  @override
  Future<CommandPayload<AuthLoginView>> load() {
    return service.login(
      allowPrompt: true,
      useStdinJson: argResults!['stdin-json'] as bool,
    );
  }

  @override
  void validateInputs() {
    if (argResults!['stdin-json'] as bool && terminal.canPrompt) {
      return;
    }
  }

  @override
  Object? toJson(AuthLoginView value) => value.toJson();

  @override
  String toText(AuthLoginView value) {
    return [
      'Authenticated: ${value.authenticated ? 'yes' : 'no'}',
      'Credential source: ${value.credentialSource}',
      'Reusable without prompting: ${value.reusable ? 'yes' : 'no'}',
      'Checked at: ${value.checkedAt}',
    ].join('\n');
  }
}

final class AuthStatusCommand extends KlasCommand<AuthStatusView> {
  AuthStatusCommand(super.terminal, super.service);

  @override
  String get name => 'status';

  @override
  String get description =>
      'Check whether reusable auth is currently available.';

  @override
  Future<CommandPayload<AuthStatusView>> load() => service.authStatus();

  @override
  Object? toJson(AuthStatusView value) => value.toJson();

  @override
  String toText(AuthStatusView value) {
    return [
      'Authenticated: ${value.authenticated ? 'yes' : 'no'}',
      'Credential source: ${value.credentialSource}',
      'Reusable without prompting: ${value.reusable ? 'yes' : 'no'}',
      'Interactive prompt available: ${value.interactiveAvailable ? 'yes' : 'no'}',
      'Checked at: ${value.checkedAt}',
      if (value.hint != null) 'Hint: ${value.hint}',
    ].join('\n');
  }
}

final class AuthDaemonServeCommand extends Command<int> {
  AuthDaemonServeCommand(AuthSessionManager sessionManager) {
    argParser.addOption('metadata-file', mandatory: true);
  }

  @override
  String get name => '__authd';

  @override
  bool get hidden => true;

  @override
  String get description => 'Internal reusable auth session daemon.';

  @override
  Future<int> run() {
    final metadataFile = argResults!['metadata-file'] as String;
    return runAuthSessionDaemon(metadataFilePath: metadataFile);
  }
}

final class AuthLogoutCommand extends KlasCommand<SimpleMessageView> {
  AuthLogoutCommand(super.terminal, super.service);

  @override
  String get name => 'logout';

  @override
  String get description =>
      'Clear the durable local auth state managed by this CLI.';

  @override
  Future<CommandPayload<SimpleMessageView>> load() => service.logout();

  @override
  Object? toJson(SimpleMessageView value) => value.toJson();

  @override
  String toText(SimpleMessageView value) {
    return [
      value.message,
      if (value.hint != null) 'Hint: ${value.hint}',
    ].join('\n');
  }
}

final class MeGroupCommand extends Command<int> {
  MeGroupCommand(Terminal terminal, KlasService service) {
    addSubcommand(MeProfileCommand(terminal, service));
  }

  @override
  String get name => 'me';

  @override
  String get description => 'Read-only commands about the authenticated user.';
}

final class MeProfileCommand extends KlasCommand<ProfileView> {
  MeProfileCommand(super.terminal, super.service);

  @override
  String get name => 'profile';

  @override
  String get description =>
      'Show the current user profile without exposing student IDs.';

  @override
  Future<CommandPayload<ProfileView>> load() {
    return service.profile(allowPrompt: allowPrompt);
  }

  @override
  Object? toJson(ProfileView value) => value.toJson();

  @override
  String toText(ProfileView value) {
    return [
      'Authenticated: ${value.authenticated ? 'yes' : 'no'}',
      'Name: ${value.name ?? '-'}',
      'Email: ${value.email ?? '-'}',
      'Mobile: ${value.mobilePhone ?? '-'}',
      'Birthday: ${value.birthday ?? '-'}',
    ].join('\n');
  }
}

final class CoursesGroupCommand extends Command<int> {
  CoursesGroupCommand(Terminal terminal, KlasService service) {
    addSubcommand(CoursesListCommand(terminal, service));
    addSubcommand(CoursesShowCommand(terminal, service));
  }

  @override
  String get name => 'courses';

  @override
  String get description => 'List and inspect course contexts.';
}

final class CoursesListCommand extends KlasCommand<List<CourseView>> {
  CoursesListCommand(super.terminal, super.service);

  @override
  String get name => 'list';

  @override
  String get description => 'List all current course contexts.';

  @override
  Future<CommandPayload<List<CourseView>>> load() {
    return service.listCourses(allowPrompt: allowPrompt);
  }

  @override
  Object? toJson(List<CourseView> value) {
    return value.map((item) => item.toJson()).toList(growable: false);
  }

  @override
  String toText(List<CourseView> value) {
    if (value.isEmpty) {
      return 'No courses found.';
    }
    return value
        .map(
          (course) =>
              '${course.title ?? course.courseId} [${course.courseId}] | professor=${course.professorName ?? '-'} | term=${course.termId}${course.isDefault ? ' | default' : ''}',
        )
        .join('\n');
  }
}

final class CoursesShowCommand extends KlasCommand<CourseView> {
  CoursesShowCommand(super.terminal, super.service) {
    argParser.addOption(
      'course',
      help: 'Exact course id or exact course title.',
    );
  }

  @override
  String get name => 'show';

  @override
  String get description => 'Show one course by exact id or exact title.';

  @override
  void validateInputs() {
    final selector = argResults!['course'] as String?;
    if (selector == null) {
      throw const CliException(
        code: 'USAGE_ERROR',
        message: 'Missing required option: --course',
        exitCode: ExitCodes.usage,
        hint: 'Example: klas courses show --course CSE101',
      );
    }
    validateCourseSelector(selector);
  }

  @override
  Future<CommandPayload<CourseView>> load() {
    return service.showCourse(
      argResults!['course'] as String,
      allowPrompt: allowPrompt,
    );
  }

  @override
  Object? toJson(CourseView value) => value.toJson();

  @override
  String toText(CourseView value) {
    return [
      'Title: ${value.title ?? '-'}',
      'Course ID: ${value.courseId}',
      'Term ID: ${value.termId}',
      'Professor: ${value.professorName ?? '-'}',
      'Default course: ${value.isDefault ? 'yes' : 'no'}',
      'Schedule: ${value.scheduleText ?? '-'}',
    ].join('\n');
  }
}

final class TasksGroupCommand extends Command<int> {
  TasksGroupCommand(Terminal terminal, KlasService service) {
    addSubcommand(TasksListCommand(terminal, service));
    addSubcommand(TasksShowCommand(terminal, service));
  }

  @override
  String get name => 'tasks';

  @override
  String get description => 'List tasks and inspect a single task.';
}

final class TasksListCommand extends KlasCommand<List<TaskView>> {
  TasksListCommand(super.terminal, super.service) {
    argParser.addOption(
      'course',
      help: 'Exact course id or exact course title.',
    );
  }

  @override
  String get name => 'list';

  @override
  String get description =>
      'List tasks across courses, with an optional course filter.';

  @override
  void validateInputs() {
    final selector = argResults!['course'] as String?;
    if (selector != null) {
      validateCourseSelector(selector);
    }
  }

  @override
  Future<CommandPayload<List<TaskView>>> load() {
    return service.listTasks(
      allowPrompt: allowPrompt,
      courseSelector: argResults!['course'] as String?,
    );
  }

  @override
  Object? toJson(List<TaskView> value) {
    return value.map((item) => item.toJson()).toList(growable: false);
  }

  @override
  String toText(List<TaskView> value) {
    if (value.isEmpty) {
      return 'No tasks found.';
    }
    return value
        .map(
          (task) =>
              '[${task.courseTitle}] #${task.taskNo} ${task.title ?? '-'} | due=${task.dueAt ?? '-'} | status=${task.submissionStatus.value}',
        )
        .join('\n');
  }
}

final class TasksShowCommand extends KlasCommand<TaskView> {
  TasksShowCommand(super.terminal, super.service) {
    argParser.addOption(
      'course',
      help: 'Exact course id or exact course title.',
    );
  }

  @override
  String get name => 'show';

  @override
  String get description =>
      'Show one task by task number, optionally narrowed by course.';

  @override
  String get invocation =>
      '${runner!.executableName} tasks show <task_no> [arguments]';

  @override
  void validateInputs() {
    final selector = argResults!['course'] as String?;
    if (selector != null) {
      validateCourseSelector(selector);
    }
    if (argResults!.rest.length != 1) {
      throw const CliException(
        code: 'USAGE_ERROR',
        message: 'Provide exactly one task number.',
        exitCode: ExitCodes.usage,
        hint: 'Example: klas tasks show 12 --course CSE101',
      );
    }
    final taskNo = int.tryParse(argResults!.rest.single);
    if (taskNo == null) {
      throw const CliException(
        code: 'USAGE_ERROR',
        message: 'Task number must be an integer.',
        exitCode: ExitCodes.usage,
      );
    }
  }

  @override
  Future<CommandPayload<TaskView>> load() async {
    final taskNo = int.parse(argResults!.rest.single);

    return service.showTask(
      taskNo,
      allowPrompt: allowPrompt,
      courseSelector: argResults!['course'] as String?,
    );
  }

  @override
  Object? toJson(TaskView value) => value.toJson();

  @override
  String toText(TaskView value) {
    return [
      'Course: ${value.courseTitle} [${value.courseId}]',
      'Professor: ${value.professorName ?? '-'}',
      'Task #: ${value.taskNo}',
      'Title: ${value.title ?? '-'}',
      'Start: ${value.startAt ?? '-'}',
      'Due: ${value.dueAt ?? '-'}',
      'Submission status: ${value.submissionStatus.value}',
      'Report title: ${value.reportTitle ?? '-'}',
      'Submission text: ${value.submissionText ?? '-'}',
    ].join('\n');
  }
}

final class NoticesGroupCommand extends Command<int> {
  NoticesGroupCommand(Terminal terminal, KlasService service) {
    addSubcommand(NoticesListCommand(terminal, service));
  }

  @override
  String get name => 'notices';

  @override
  String get description => 'List course notices.';
}

final class NoticesListCommand extends KlasCommand<List<NoticeView>> {
  NoticesListCommand(super.terminal, super.service) {
    argParser.addOption(
      'course',
      help: 'Exact course id or exact course title.',
    );
  }

  @override
  String get name => 'list';

  @override
  String get description =>
      'List notices across courses, with an optional course filter.';

  @override
  void validateInputs() {
    final selector = argResults!['course'] as String?;
    if (selector != null) {
      validateCourseSelector(selector);
    }
  }

  @override
  Future<CommandPayload<List<NoticeView>>> load() {
    return service.listNotices(
      allowPrompt: allowPrompt,
      courseSelector: argResults!['course'] as String?,
    );
  }

  @override
  Object? toJson(List<NoticeView> value) {
    return value.map((item) => item.toJson()).toList(growable: false);
  }

  @override
  String toText(List<NoticeView> value) {
    if (value.isEmpty) {
      return 'No notices found.';
    }
    return value
        .map(
          (notice) =>
              '[${notice.courseTitle}] #${notice.boardNo} ${notice.title ?? '-'} | posted=${notice.postedAt ?? '-'} | attachments=${notice.hasAttachments ? notice.fileCount : 0}',
        )
        .join('\n');
  }
}

final class ScheduleGroupCommand extends Command<int> {
  ScheduleGroupCommand(Terminal terminal, KlasService service) {
    addSubcommand(ScheduleTodayCommand(terminal, service));
    addSubcommand(ScheduleWeekCommand(terminal, service));
    addSubcommand(ScheduleNextCommand(terminal, service));
  }

  @override
  String get name => 'schedule';

  @override
  String get description => 'Show today, week, or next schedule items.';
}

final class ScheduleTodayCommand extends KlasCommand<List<ScheduleView>> {
  ScheduleTodayCommand(super.terminal, super.service);

  @override
  String get name => 'today';

  @override
  String get description => 'Show schedule items for today.';

  @override
  Future<CommandPayload<List<ScheduleView>>> load() {
    return service.scheduleToday(allowPrompt: allowPrompt);
  }

  @override
  Object? toJson(List<ScheduleView> value) {
    return value.map((item) => item.toJson()).toList(growable: false);
  }

  @override
  String toText(List<ScheduleView> value) =>
      _renderScheduleList(value, empty: 'No schedule items for today.');
}

final class ScheduleWeekCommand extends KlasCommand<List<ScheduleView>> {
  ScheduleWeekCommand(super.terminal, super.service);

  @override
  String get name => 'week';

  @override
  String get description => 'Show weekly recurring timetable entries.';

  @override
  Future<CommandPayload<List<ScheduleView>>> load() {
    return service.scheduleWeek(allowPrompt: allowPrompt);
  }

  @override
  Object? toJson(List<ScheduleView> value) {
    return value.map((item) => item.toJson()).toList(growable: false);
  }

  @override
  String toText(List<ScheduleView> value) =>
      _renderScheduleList(value, empty: 'No weekly schedule entries found.');
}

final class ScheduleNextCommand extends KlasCommand<ScheduleView?> {
  ScheduleNextCommand(super.terminal, super.service);

  @override
  String get name => 'next';

  @override
  String get description => 'Show the next upcoming schedule item.';

  @override
  Future<CommandPayload<ScheduleView?>> load() {
    return service.scheduleNext(allowPrompt: allowPrompt);
  }

  @override
  Object? toJson(ScheduleView? value) => value?.toJson();

  @override
  String toText(ScheduleView? value) {
    if (value == null) {
      return 'No upcoming schedule item found.';
    }
    return _renderSchedule(value);
  }
}

final class SchemaCommand extends KlasCommand<Object?> {
  SchemaCommand(super.terminal, super.service);

  @override
  String get name => 'schema';

  @override
  String get description =>
      'Describe commands, flags, and normalized JSON output fields.';

  @override
  String get commandPath => 'schema';

  @override
  CommandContract get contract => contractForPath('schema');

  @override
  Future<CommandPayload<Object?>> load() async {
    final path = argResults!.rest.join(' ').trim();
    return CommandPayload<Object?>(
      data: schemaForPath(path.isEmpty ? null : path),
      meta: <String, Object?>{'runtime_introspection': true},
    );
  }

  @override
  Object? toJson(Object? value) => value;

  @override
  String toText(Object? value) {
    if (value is! Map<String, Object?>) {
      return 'No schema data available.';
    }

    final path = value['path'];
    final description = value['description'];
    final subcommands = value['subcommands'];
    final outputFields = value['output_fields'];
    return [
      'Path: ${path ?? 'klas'}',
      if (description != null) 'Description: $description',
      if (subcommands is List && subcommands.isNotEmpty)
        'Subcommands: ${subcommands.join(', ')}',
      if (outputFields is List && outputFields.isNotEmpty)
        'Output fields: ${outputFields.join(', ')}',
    ].join('\n');
  }
}

String _renderScheduleList(List<ScheduleView> items, {required String empty}) {
  if (items.isEmpty) {
    return empty;
  }
  return items.map(_renderSchedule).join('\n');
}

String _renderSchedule(ScheduleView item) {
  return '${item.title} | kind=${item.kind.value} | day=${item.dayOfWeek ?? '-'} | start=${item.startsAt ?? '-'} | room=${item.classroom ?? '-'}';
}
