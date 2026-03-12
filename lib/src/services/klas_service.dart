import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:klasflow/klasflow.dart';

import '../auth/session_manager.dart';
import '../auth/session_metadata.dart';
import '../auth/terminal.dart';
import '../errors/cli_errors.dart';
import '../models/cli_models.dart';
import '../validation/input_validation.dart';

typedef KlasClientFactory = KlasClient Function();

abstract interface class KlasService {
  Future<CommandPayload<AuthLoginView>> login({
    required bool allowPrompt,
    required bool useStdinJson,
  });

  Future<CommandPayload<AuthStatusView>> authStatus();

  Future<CommandPayload<SimpleMessageView>> logout();

  Future<CommandPayload<ProfileView>> profile({required bool allowPrompt});

  Future<CommandPayload<List<CourseView>>> listCourses({
    required bool allowPrompt,
  });

  Future<CommandPayload<CourseView>> showCourse(
    String selector, {
    required bool allowPrompt,
  });

  Future<CommandPayload<List<TaskView>>> listTasks({
    required bool allowPrompt,
    String? courseSelector,
  });

  Future<CommandPayload<TaskView>> showTask(
    int taskNo, {
    required bool allowPrompt,
    String? courseSelector,
  });

  Future<CommandPayload<List<NoticeView>>> listNotices({
    required bool allowPrompt,
    String? courseSelector,
  });

  Future<CommandPayload<List<ScheduleView>>> scheduleToday({
    required bool allowPrompt,
  });

  Future<CommandPayload<List<ScheduleView>>> scheduleWeek({
    required bool allowPrompt,
  });

  Future<CommandPayload<ScheduleView?>> scheduleNext({
    required bool allowPrompt,
  });
}

final class KlasflowService implements KlasService {
  KlasflowService({
    required Terminal terminal,
    required AuthSessionManager sessionManager,
    Map<String, String>? environment,
    KlasClientFactory? clientFactory,
  }) : _terminal = terminal,
       _sessionManager = sessionManager,
       _environment = environment ?? Platform.environment,
       _clientFactory = clientFactory ?? KlasClient.new;

  final Terminal _terminal;
  final AuthSessionManager _sessionManager;
  final Map<String, String> _environment;
  final KlasClientFactory _clientFactory;

  @override
  Future<CommandPayload<AuthLoginView>> login({
    required bool allowPrompt,
    required bool useStdinJson,
  }) async {
    final credentials = await _resolveCredentials(
      allowPrompt: allowPrompt,
      useSession: false,
      useStdinJson: useStdinJson,
    );
    await _withCredentials(credentials, (client, _, source) async {
      await _sessionManager.save(
        SessionCredentials(id: credentials.id, password: credentials.password),
      );
      return source;
    });

    return CommandPayload<AuthLoginView>(
      data: AuthLoginView(
        authenticated: true,
        credentialSource: credentials.source.value,
        reusable: true,
        checkedAt: _nowIso(),
      ),
      meta: <String, Object?>{
        'auth_mode': credentials.source.value,
        'reusable': true,
      },
    );
  }

  @override
  Future<CommandPayload<AuthStatusView>> authStatus() async {
    final credentials = await _sessionCredentials();
    if (credentials == null) {
      final envCredentials = _envCredentials();
      if (envCredentials != null) {
        try {
          return await _withCredentials(envCredentials, (
            client,
            _,
            source,
          ) async {
            return CommandPayload<AuthStatusView>(
              data: AuthStatusView(
                authenticated: true,
                reusable: true,
                credentialSource: source.value,
                checkedAt: _nowIso(),
                interactiveAvailable: _terminal.canPrompt,
              ),
            );
          });
        } on InvalidCredentialsException {
          return CommandPayload<AuthStatusView>(
            data: AuthStatusView(
              authenticated: false,
              reusable: true,
              credentialSource: CredentialSource.env.value,
              checkedAt: _nowIso(),
              interactiveAvailable: _terminal.canPrompt,
              hint:
                  'Environment credentials are present but were rejected by KLAS.',
            ),
          );
        }
      }

      return CommandPayload<AuthStatusView>(
        data: AuthStatusView(
          authenticated: false,
          reusable: false,
          credentialSource: CredentialSource.none.value,
          checkedAt: _nowIso(),
          interactiveAvailable: _terminal.canPrompt,
          hint:
              'No reusable auth session is available. Run `klas auth login` or set KLAS_ID and KLAS_PASSWORD.',
        ),
      );
    }

    try {
      return await _withCredentials(credentials, (client, _, source) async {
        return CommandPayload<AuthStatusView>(
          data: AuthStatusView(
            authenticated: true,
            reusable: true,
            credentialSource: source.value,
            checkedAt: _nowIso(),
            interactiveAvailable: _terminal.canPrompt,
          ),
        );
      });
    } on InvalidCredentialsException {
      if (credentials.source == CredentialSource.session) {
        await _sessionManager.clear();
      }
      return CommandPayload<AuthStatusView>(
        data: AuthStatusView(
          authenticated: false,
          reusable: true,
          credentialSource: credentials.source.value,
          checkedAt: _nowIso(),
          interactiveAvailable: _terminal.canPrompt,
          hint: credentials.source == CredentialSource.session
              ? 'The stored local auth session is no longer valid and was cleared.'
              : 'Environment credentials are present but were rejected by KLAS.',
        ),
      );
    }
  }

  @override
  Future<CommandPayload<SimpleMessageView>> logout() async {
    await _sessionManager.clear();
    return const CommandPayload<SimpleMessageView>(
      data: SimpleMessageView(
        message: 'Cleared the local reusable auth session managed by this CLI.',
        hint:
            'If you also configured KLAS_ID and KLAS_PASSWORD in your shell, remove them there to prevent automatic fallback.',
      ),
    );
  }

  @override
  Future<CommandPayload<ProfileView>> profile({
    required bool allowPrompt,
  }) async {
    return _withUser(
      allowPrompt: allowPrompt,
      action: (client, user, _) async {
        final profileFuture = user.profile(refresh: true);
        final personalInfoFuture = user.personalInfo(refresh: true);
        await Future.wait<Object?>(<Future<Object?>>[
          profileFuture,
          personalInfoFuture,
        ]);
        final profile = await profileFuture;
        final personalInfo = await personalInfoFuture;
        return CommandPayload<ProfileView>(
          data: ProfileView(
            authenticated: profile.authenticated,
            name: personalInfo.userName ?? profile.userName,
            email: personalInfo.email,
            mobilePhone: personalInfo.mobilePhone,
            birthday: _normalizeDate(personalInfo.birthday),
          ),
        );
      },
    );
  }

  @override
  Future<CommandPayload<List<CourseView>>> listCourses({
    required bool allowPrompt,
  }) async {
    return _withUser(
      allowPrompt: allowPrompt,
      action: (client, user, _) async {
        final courses = await user.courses(refresh: true);
        final data =
            courses
                .map(
                  (course) => CourseView(
                    courseId: course.courseId,
                    termId: course.termId,
                    title: course.title,
                    professorName: course.professorName,
                    isDefault: course.isDefault,
                  ),
                )
                .toList(growable: false)
              ..sort(
                (left, right) => (left.title ?? left.courseId).compareTo(
                  right.title ?? right.courseId,
                ),
              );

        return CommandPayload<List<CourseView>>(
          data: data,
          meta: <String, Object?>{'count': data.length},
        );
      },
    );
  }

  @override
  Future<CommandPayload<CourseView>> showCourse(
    String selector, {
    required bool allowPrompt,
  }) async {
    return _withUser(
      allowPrompt: allowPrompt,
      action: (client, user, _) async {
        final course = await _selectSingleCourse(user, selector);
        final scheduleText = await course.scheduleText();
        return CommandPayload<CourseView>(
          data: CourseView(
            courseId: course.courseId,
            termId: course.termId,
            title: course.title,
            professorName: course.professorName,
            isDefault: course.isDefault,
            scheduleText: scheduleText,
          ),
        );
      },
    );
  }

  @override
  Future<CommandPayload<List<TaskView>>> listTasks({
    required bool allowPrompt,
    String? courseSelector,
  }) async {
    return _withUser(
      allowPrompt: allowPrompt,
      action: (client, user, _) async {
        final courses = await _selectCourses(user, courseSelector);
        final data = <TaskView>[];
        final warnings = <String>[];
        final results = await Future.wait(
          courses.map(_loadTasksForCourseSafely),
        );

        for (final result in results) {
          if (result.warning != null) {
            warnings.add(result.warning!);
            continue;
          }
          data.addAll(
            result.tasks
                .map(
                  (task) => TaskView(
                    courseId: result.course.courseId,
                    courseTitle: result.course.title ?? result.course.courseId,
                    professorName: result.course.professorName,
                    taskNo: task.taskNo ?? -1,
                    title: task.title,
                    startAt: _normalizeDateTime(task.startDate),
                    dueAt: _normalizeDateTime(task.expireDate),
                    submissionStatus: _submissionStatus(task.submitted),
                  ),
                )
                .where((task) => task.taskNo >= 0),
          );
        }

        data.sort(_compareTaskViews);
        return CommandPayload<List<TaskView>>(
          data: data,
          meta: <String, Object?>{
            'count': data.length,
            'courses_scanned': courses.length,
            'course_filter': courseSelector,
          },
          warnings: warnings,
        );
      },
    );
  }

  @override
  Future<CommandPayload<TaskView>> showTask(
    int taskNo, {
    required bool allowPrompt,
    String? courseSelector,
  }) async {
    return _withUser(
      allowPrompt: allowPrompt,
      action: (client, user, _) async {
        final courses = await _selectCourses(user, courseSelector);
        final taskLoads = await Future.wait(
          courses.map(
            (course) async =>
                (course: course, tasks: await _loadAllTasks(course)),
          ),
        );
        final matches = <(KlasCourse, KlasTask)>[];

        for (final load in taskLoads) {
          for (final task in load.tasks) {
            if (task.taskNo == taskNo) {
              matches.add((load.course, task));
            }
          }
        }

        if (matches.isEmpty) {
          throw const CliException(
            code: 'TASK_NOT_FOUND',
            message: 'No task matched the requested task number.',
            exitCode: ExitCodes.notFound,
            hint:
                'Run `klas tasks list` first, or pass --course to narrow the search.',
          );
        }
        if (matches.length > 1 &&
            (courseSelector == null || courseSelector.trim().isEmpty)) {
          throw const CliException(
            code: 'AMBIGUOUS_INPUT',
            message:
                'Multiple tasks share that task number across different courses.',
            exitCode: ExitCodes.usage,
            hint: 'Pass --course with an exact course id or title.',
          );
        }

        final selected = matches.first;
        final detail = await selected.$1.learning.getTaskDetail(ordseq: taskNo);
        return CommandPayload<TaskView>(
          data: TaskView(
            courseId: selected.$1.courseId,
            courseTitle: selected.$1.title ?? selected.$1.courseId,
            professorName: selected.$1.professorName,
            taskNo: taskNo,
            title: selected.$2.title,
            startAt: _normalizeDateTime(selected.$2.startDate),
            dueAt: _normalizeDateTime(selected.$2.expireDate),
            submissionStatus: _submissionStatus(selected.$2.submitted),
            reportTitle: detail.reportTitle,
            reportHtml: detail.reportHtml,
            submissionText: detail.submissionText,
          ),
        );
      },
    );
  }

  @override
  Future<CommandPayload<List<NoticeView>>> listNotices({
    required bool allowPrompt,
    String? courseSelector,
  }) async {
    return _withUser(
      allowPrompt: allowPrompt,
      action: (client, user, _) async {
        final courses = await _selectCourses(user, courseSelector);
        final data = <NoticeView>[];
        final warnings = <String>[];
        final results = await Future.wait(
          courses.map(_loadNoticesForCourseSafely),
        );

        for (final result in results) {
          if (result.warning != null) {
            warnings.add(result.warning!);
            continue;
          }
          data.addAll(
            result.notices
                .map(
                  (notice) => NoticeView(
                    courseId: result.course.courseId,
                    courseTitle: result.course.title ?? result.course.courseId,
                    boardNo: notice.boardNo ?? -1,
                    title: notice.title,
                    authorName: notice.authorName,
                    postedAt: _normalizeDateTime(notice.registeredAt),
                    hasAttachments: notice.hasAttachments,
                    fileCount: notice.fileCount ?? 0,
                  ),
                )
                .where((notice) => notice.boardNo >= 0),
          );
        }

        data.sort(
          (left, right) =>
              (right.postedAt ?? '').compareTo(left.postedAt ?? ''),
        );
        return CommandPayload<List<NoticeView>>(
          data: data,
          meta: <String, Object?>{
            'count': data.length,
            'courses_scanned': courses.length,
            'course_filter': courseSelector,
          },
          warnings: warnings,
        );
      },
    );
  }

  @override
  Future<CommandPayload<List<ScheduleView>>> scheduleToday({
    required bool allowPrompt,
  }) async {
    return _withUser(
      allowPrompt: allowPrompt,
      action: (client, user, _) async {
        final timetableFuture = user.timetable();
        final monthlyFuture = user.attendance.listMonthlySchedules();
        await Future.wait<Object?>(<Future<Object?>>[
          timetableFuture,
          monthlyFuture,
        ]);
        final timetable = await timetableFuture;
        final monthly = await monthlyFuture;
        final today = DateTime.now();
        final weekday = _weekdayLabel(today.weekday);

        final classItems = timetable.entries
            .where((entry) => entry.dayOfWeek == weekday)
            .map(_mapTimetableEntry)
            .toList(growable: false);
        final calendarItems = monthly
            .where((item) => _matchesDate(item.date, today))
            .map(_mapMonthlySchedule)
            .toList(growable: false);
        final data = <ScheduleView>[...classItems, ...calendarItems]
          ..sort(_compareScheduleViews);

        return CommandPayload<List<ScheduleView>>(
          data: data,
          meta: <String, Object?>{
            'count': data.length,
            'basis': 'timetable+monthly_schedule',
            'date': _normalizeDate(today.toIso8601String()),
          },
        );
      },
    );
  }

  @override
  Future<CommandPayload<List<ScheduleView>>> scheduleWeek({
    required bool allowPrompt,
  }) async {
    return _withUser(
      allowPrompt: allowPrompt,
      action: (client, user, _) async {
        final timetable = await user.timetable();
        final data =
            timetable.entries.map(_mapTimetableEntry).toList(growable: false)
              ..sort(_compareScheduleViews);
        return CommandPayload<List<ScheduleView>>(
          data: data,
          meta: <String, Object?>{'count': data.length, 'basis': 'timetable'},
        );
      },
    );
  }

  @override
  Future<CommandPayload<ScheduleView?>> scheduleNext({
    required bool allowPrompt,
  }) async {
    return _withUser(
      allowPrompt: allowPrompt,
      action: (client, user, _) async {
        final now = DateTime.now();
        final timetableFuture = user.timetable();
        final monthlyFuture = user.attendance.listMonthlySchedules();
        await Future.wait<Object?>(<Future<Object?>>[
          timetableFuture,
          monthlyFuture,
        ]);
        final timetable = await timetableFuture;
        final monthly = await monthlyFuture;
        final candidates = <(DateTime, ScheduleView)>[];

        for (final entry in timetable.entries) {
          final occurrence = _nextOccurrenceForEntry(entry, now);
          if (occurrence == null) {
            continue;
          }
          candidates.add((
            occurrence,
            _mapTimetableEntry(entry, startsAt: occurrence.toIso8601String()),
          ));
        }

        for (final item in monthly) {
          final occurrence = _parseDateOnly(item.date);
          if (occurrence == null ||
              occurrence.isBefore(DateTime(now.year, now.month, now.day))) {
            continue;
          }
          candidates.add((occurrence, _mapMonthlySchedule(item)));
        }

        candidates.sort((left, right) => left.$1.compareTo(right.$1));
        final next = candidates.isEmpty ? null : candidates.first.$2;

        return CommandPayload<ScheduleView?>(
          data: next,
          meta: <String, Object?>{
            'basis': 'timetable+monthly_schedule',
            'found': next != null,
          },
        );
      },
    );
  }

  Future<T> _withUser<T>({
    required bool allowPrompt,
    required Future<T> Function(
      KlasClient client,
      KlasUser user,
      CredentialSource source,
    )
    action,
  }) async {
    final credentials = await _resolveCredentials(allowPrompt: allowPrompt);
    return _withCredentials(credentials, action);
  }

  Future<T> _withCredentials<T>(
    _ResolvedCredentials credentials,
    Future<T> Function(
      KlasClient client,
      KlasUser user,
      CredentialSource source,
    )
    action,
  ) async {
    final client = _clientFactory();
    try {
      final user = await client.login(credentials.id, credentials.password);
      return await action(client, user, credentials.source);
    } finally {
      client.close();
    }
  }

  Future<_ResolvedCredentials> _resolveCredentials({
    required bool allowPrompt,
    bool useSession = true,
    bool useStdinJson = false,
  }) async {
    if (useStdinJson) {
      return _stdinJsonCredentials();
    }

    if (useSession) {
      final sessionCredentials = await _sessionCredentials();
      if (sessionCredentials != null) {
        return sessionCredentials;
      }
    }

    final envCredentials = _envCredentials();
    if (envCredentials != null) {
      return envCredentials;
    }

    if (!allowPrompt || !_terminal.canPrompt) {
      throw const CliException(
        code: 'AUTH_REQUIRED',
        message: 'Authentication is required for this command.',
        exitCode: ExitCodes.auth,
        hint:
            'Set KLAS_ID and KLAS_PASSWORD or run the command in an interactive terminal.',
      );
    }

    final id = (await _terminal.prompt('KLAS ID: '))?.trim();
    final password = await _terminal.prompt('Password: ', secret: true);
    if (id == null || id.isEmpty || password == null || password.isEmpty) {
      throw const CliException(
        code: 'AUTH_REQUIRED',
        message:
            'Authentication was cancelled because credentials were incomplete.',
        exitCode: ExitCodes.auth,
        hint:
            'Provide both an ID and password, or set KLAS_ID and KLAS_PASSWORD.',
      );
    }

    return _ResolvedCredentials(
      id: id,
      password: password,
      source: CredentialSource.prompt,
    );
  }

  Future<_ResolvedCredentials> _stdinJsonCredentials() async {
    final raw = await stdin.transform(utf8.decoder).join();
    if (raw.trim().isEmpty) {
      throw const CliException(
        code: 'AUTH_REQUIRED',
        message:
            'Expected JSON credentials on stdin, but no input was provided.',
        exitCode: ExitCodes.auth,
        hint: 'Provide {"id":"...","password":"..."} via stdin.',
      );
    }

    try {
      final parsed = (jsonDecode(raw) as Map<String, dynamic>)
          .cast<String, Object?>();
      final rawId = parsed['id'] as String?;
      final rawPassword = parsed['password'] as String?;
      final id = rawId == null
          ? null
          : validateNoControlChars(
              rawId,
              fieldName: 'id',
              emptyHint: 'Provide {"id":"...","password":"..."} via stdin.',
            );
      final password = rawPassword == null
          ? null
          : validateNoControlChars(
              rawPassword,
              fieldName: 'password',
              emptyHint: 'Provide {"id":"...","password":"..."} via stdin.',
            );
      if (id == null || id.isEmpty || password == null || password.isEmpty) {
        throw const FormatException('Missing id/password.');
      }
      return _ResolvedCredentials(
        id: id,
        password: password,
        source: CredentialSource.stdinJson,
      );
    } catch (_) {
      throw const CliException(
        code: 'USAGE_ERROR',
        message:
            'stdin JSON credentials must be an object with non-empty string fields `id` and `password`.',
        exitCode: ExitCodes.usage,
      );
    }
  }

  Future<_ResolvedCredentials?> _sessionCredentials() async {
    final credentials = await _sessionManager.load();
    if (credentials == null) {
      return null;
    }
    return _ResolvedCredentials(
      id: validateNoControlChars(credentials.id, fieldName: 'session id'),
      password: validateNoControlChars(
        credentials.password,
        fieldName: 'session password',
      ),
      source: CredentialSource.session,
    );
  }

  _ResolvedCredentials? _envCredentials() {
    final rawId = _environment['KLAS_ID'];
    final rawPassword = _environment['KLAS_PASSWORD'];
    final id = rawId == null
        ? null
        : validateNoControlChars(rawId, fieldName: 'KLAS_ID');
    final password = rawPassword == null
        ? null
        : validateNoControlChars(rawPassword, fieldName: 'KLAS_PASSWORD');
    if (id == null || id.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return _ResolvedCredentials(
      id: id,
      password: password,
      source: CredentialSource.env,
    );
  }

  Future<List<KlasCourse>> _selectCourses(
    KlasUser user,
    String? selector,
  ) async {
    final courses = await user.courses(refresh: true);
    if (selector == null || selector.trim().isEmpty) {
      return courses;
    }

    final normalized = validateCourseSelector(selector).toLowerCase();
    final matches = courses
        .where((course) {
          return course.courseId.toLowerCase() == normalized ||
              (course.title?.trim().toLowerCase() == normalized);
        })
        .toList(growable: false);

    if (matches.isEmpty) {
      throw const CliException(
        code: 'COURSE_NOT_FOUND',
        message: 'No course matched the provided selector.',
        exitCode: ExitCodes.notFound,
        hint:
            'Use an exact course id or exact course title from `klas courses list`.',
      );
    }
    if (matches.length > 1) {
      throw const CliException(
        code: 'AMBIGUOUS_INPUT',
        message: 'The course selector matched more than one course.',
        exitCode: ExitCodes.usage,
        hint: 'Use an exact course id to disambiguate.',
      );
    }
    return matches;
  }

  Future<KlasCourse> _selectSingleCourse(KlasUser user, String selector) async {
    return (await _selectCourses(user, selector)).single;
  }

  Future<List<KlasTask>> _loadAllTasks(KlasCourse course) async {
    final items = <KlasTask>[];
    final seenKeys = <String>{};
    for (var page = 0; page < 20; page++) {
      final pageItems = await course.listTasks(page: page);
      if (pageItems.isEmpty) {
        break;
      }
      var added = 0;
      for (final task in pageItems) {
        final key = '${task.taskNo}|${task.title}|${task.expireDate}';
        if (seenKeys.add(key)) {
          items.add(task);
          added++;
        }
      }
      if (added == 0) {
        break;
      }
    }
    return items;
  }

  Future<List<KlasBoardPostSummary>> _loadAllNotices(KlasCourse course) async {
    final items = <KlasBoardPostSummary>[];
    var page = 0;
    while (page < 20) {
      final result = await course.noticeBoard.listPosts(page: page);
      items.addAll(result.posts);
      final pageInfo = result.page;
      if (pageInfo?.totalPages == null || page + 1 >= pageInfo!.totalPages!) {
        break;
      }
      page++;
    }
    return items;
  }

  TaskSubmissionStatus _submissionStatus(bool? submitted) {
    return switch (submitted) {
      true => TaskSubmissionStatus.submitted,
      false => TaskSubmissionStatus.notSubmitted,
      null => TaskSubmissionStatus.unknown,
    };
  }

  Future<_CourseTaskLoadResult> _loadTasksForCourseSafely(
    KlasCourse course,
  ) async {
    try {
      return _CourseTaskLoadResult(
        course: course,
        tasks: await _loadAllTasks(course),
      );
    } catch (error) {
      return _CourseTaskLoadResult(
        course: course,
        tasks: const <KlasTask>[],
        warning:
            'Failed to load tasks for ${course.title ?? course.courseId}: ${_describeWarning(error)}',
      );
    }
  }

  Future<_CourseNoticeLoadResult> _loadNoticesForCourseSafely(
    KlasCourse course,
  ) async {
    try {
      return _CourseNoticeLoadResult(
        course: course,
        notices: await _loadAllNotices(course),
      );
    } catch (error) {
      return _CourseNoticeLoadResult(
        course: course,
        notices: const <KlasBoardPostSummary>[],
        warning:
            'Failed to load notices for ${course.title ?? course.courseId}: ${_describeWarning(error)}',
      );
    }
  }
}

final class _CourseTaskLoadResult {
  const _CourseTaskLoadResult({
    required this.course,
    required this.tasks,
    this.warning,
  });

  final KlasCourse course;
  final List<KlasTask> tasks;
  final String? warning;
}

final class _CourseNoticeLoadResult {
  const _CourseNoticeLoadResult({
    required this.course,
    required this.notices,
    this.warning,
  });

  final KlasCourse course;
  final List<KlasBoardPostSummary> notices;
  final String? warning;
}

final class _ResolvedCredentials {
  const _ResolvedCredentials({
    required this.id,
    required this.password,
    required this.source,
  });

  final String id;
  final String password;
  final CredentialSource source;
}

String _nowIso() => DateTime.now().toIso8601String();

String? _normalizeDate(String? value) {
  final normalized = _normalizeDateTime(value);
  if (normalized == null) {
    return null;
  }
  final separator = normalized.indexOf('T');
  if (separator == -1) {
    return normalized;
  }
  return normalized.substring(0, separator);
}

String? _normalizeDateTime(String? value) {
  if (value == null) {
    return null;
  }
  var raw = value.trim();
  if (raw.isEmpty) {
    return null;
  }

  raw = raw.replaceAll('/', '-').replaceAll('.', '-');
  final korean = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2})시\s*(\d{1,2})분$',
  ).firstMatch(raw);
  if (korean != null) {
    return '${korean.group(1)}-${korean.group(2)}-${korean.group(3)}T${korean.group(4)!.padLeft(2, '0')}:${korean.group(5)!.padLeft(2, '0')}:00';
  }

  final full = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(raw);
  if (full != null) {
    return '${full.group(1)}-${full.group(2)}-${full.group(3)}T${full.group(4)!.padLeft(2, '0')}:${full.group(5)}:${(full.group(6) ?? '00').padLeft(2, '0')}';
  }

  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (dateOnly != null) {
    return '${dateOnly.group(1)}-${dateOnly.group(2)}-${dateOnly.group(3)}';
  }

  final compactDateTime = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$',
  ).firstMatch(raw);
  if (compactDateTime != null) {
    return '${compactDateTime.group(1)}-${compactDateTime.group(2)}-${compactDateTime.group(3)}T${compactDateTime.group(4)}:${compactDateTime.group(5)}:00';
  }

  final compactDate = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(raw);
  if (compactDate != null) {
    return '${compactDate.group(1)}-${compactDate.group(2)}-${compactDate.group(3)}';
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed != null) {
    return parsed.toIso8601String();
  }
  return raw;
}

String _describeWarning(Object error) {
  return ErrorMapper().map(error).message;
}

int _compareTaskViews(TaskView left, TaskView right) {
  final dueCompare = (left.dueAt ?? '').compareTo(right.dueAt ?? '');
  if (dueCompare != 0) {
    return dueCompare;
  }
  final courseCompare = left.courseTitle.compareTo(right.courseTitle);
  if (courseCompare != 0) {
    return courseCompare;
  }
  return left.taskNo.compareTo(right.taskNo);
}

ScheduleView _mapTimetableEntry(KlasTimetableEntry entry, {String? startsAt}) {
  return ScheduleView(
    kind: ScheduleKind.classSession,
    source: 'timetable',
    title: entry.title,
    courseTitle: entry.title,
    professorName: entry.professorName,
    classroom: entry.classroom,
    dayOfWeek: entry.dayOfWeek,
    startsAt: startsAt ?? _timeOnPlaceholderDate(entry.startTime),
    endsAt: _timeOnPlaceholderDate(entry.endTime),
  );
}

ScheduleView _mapMonthlySchedule(KlasMonthlyScheduleItem item) {
  final normalizedDate = _normalizeDateTime(item.date);
  return ScheduleView(
    kind: ScheduleKind.calendarEvent,
    source: 'monthly_schedule',
    title: item.displayTitle,
    startsAt: normalizedDate,
    status: item.status,
  );
}

String? _timeOnPlaceholderDate(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return '1970-01-01T$trimmed:00';
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => '월',
    DateTime.tuesday => '화',
    DateTime.wednesday => '수',
    DateTime.thursday => '목',
    DateTime.friday => '금',
    DateTime.saturday => '토',
    DateTime.sunday => '일',
    _ => '기타',
  };
}

bool _matchesDate(String? raw, DateTime target) {
  final parsed = _parseDateOnly(raw);
  if (parsed == null) {
    return false;
  }
  return parsed.year == target.year &&
      parsed.month == target.month &&
      parsed.day == target.day;
}

DateTime? _parseDateOnly(String? raw) {
  final normalized = _normalizeDate(raw);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}

DateTime? _nextOccurrenceForEntry(KlasTimetableEntry entry, DateTime now) {
  final weekday = switch (entry.dayOfWeek) {
    '월' => DateTime.monday,
    '화' => DateTime.tuesday,
    '수' => DateTime.wednesday,
    '목' => DateTime.thursday,
    '금' => DateTime.friday,
    '토' => DateTime.saturday,
    '일' => DateTime.sunday,
    _ => null,
  };
  if (weekday == null) {
    return null;
  }
  final startTime = entry.startTime?.split(':');
  final hour = startTime != null && startTime.length >= 2
      ? int.tryParse(startTime[0]) ?? 0
      : 0;
  final minute = startTime != null && startTime.length >= 2
      ? int.tryParse(startTime[1]) ?? 0
      : 0;

  var delta = weekday - now.weekday;
  var occurrence = DateTime(now.year, now.month, now.day + delta, hour, minute);
  if (delta < 0 || occurrence.isBefore(now)) {
    occurrence = occurrence.add(const Duration(days: 7));
  }
  return occurrence;
}

int _compareScheduleViews(ScheduleView left, ScheduleView right) {
  final dayCompare = (left.dayOfWeek ?? '').compareTo(right.dayOfWeek ?? '');
  if (dayCompare != 0) {
    return dayCompare;
  }
  final startCompare = (left.startsAt ?? '').compareTo(right.startsAt ?? '');
  if (startCompare != 0) {
    return startCompare;
  }
  return left.title.compareTo(right.title);
}
