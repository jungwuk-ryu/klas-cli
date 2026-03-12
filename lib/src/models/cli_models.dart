import 'dart:convert';

typedef JsonMap = Map<String, Object?>;

enum OutputFormat { text, json }

OutputFormat detectOutputFormat(List<String> arguments) {
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--format' && index + 1 < arguments.length) {
      return OutputFormatValue.parse(arguments[index + 1]);
    }
    if (argument.startsWith('--format=')) {
      return OutputFormatValue.parse(argument.substring('--format='.length));
    }
  }
  return OutputFormat.text;
}

extension OutputFormatValue on OutputFormat {
  static OutputFormat parse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'json' => OutputFormat.json,
      _ => OutputFormat.text,
    };
  }
}

class CommandPayload<T> {
  const CommandPayload({
    required this.data,
    this.meta = const <String, Object?>{},
    this.warnings = const <String>[],
  });

  final T data;
  final JsonMap meta;
  final List<String> warnings;
}

enum CredentialSource { env, prompt, stdinJson, session, none }

extension CredentialSourceValue on CredentialSource {
  String get value => switch (this) {
    CredentialSource.env => 'env',
    CredentialSource.prompt => 'prompt',
    CredentialSource.stdinJson => 'stdin_json',
    CredentialSource.session => 'session',
    CredentialSource.none => 'none',
  };
}

class SimpleMessageView {
  const SimpleMessageView({required this.message, this.hint});

  final String message;
  final String? hint;

  JsonMap toJson() => <String, Object?>{'message': message, 'hint': hint};
}

class AuthLoginView {
  const AuthLoginView({
    required this.authenticated,
    required this.credentialSource,
    required this.reusable,
    required this.checkedAt,
  });

  final bool authenticated;
  final String credentialSource;
  final bool reusable;
  final String checkedAt;

  JsonMap toJson() => <String, Object?>{
    'authenticated': authenticated,
    'credential_source': credentialSource,
    'reusable': reusable,
    'checked_at': checkedAt,
  };
}

class AuthStatusView {
  const AuthStatusView({
    required this.authenticated,
    required this.reusable,
    required this.credentialSource,
    required this.checkedAt,
    this.hint,
    this.interactiveAvailable = false,
  });

  final bool authenticated;
  final bool reusable;
  final String credentialSource;
  final String checkedAt;
  final String? hint;
  final bool interactiveAvailable;

  JsonMap toJson() => <String, Object?>{
    'authenticated': authenticated,
    'reusable': reusable,
    'credential_source': credentialSource,
    'checked_at': checkedAt,
    'interactive_available': interactiveAvailable,
    'hint': hint,
  };
}

class ProfileView {
  const ProfileView({
    required this.authenticated,
    this.name,
    this.email,
    this.mobilePhone,
    this.birthday,
  });

  final bool authenticated;
  final String? name;
  final String? email;
  final String? mobilePhone;
  final String? birthday;

  JsonMap toJson() => <String, Object?>{
    'authenticated': authenticated,
    'name': name,
    'email': email,
    'mobile_phone': mobilePhone,
    'birthday': birthday,
  };
}

class CourseView {
  const CourseView({
    required this.courseId,
    required this.termId,
    required this.isDefault,
    this.title,
    this.professorName,
    this.scheduleText,
  });

  final String courseId;
  final String termId;
  final bool isDefault;
  final String? title;
  final String? professorName;
  final String? scheduleText;

  JsonMap toJson() => <String, Object?>{
    'course_id': courseId,
    'term_id': termId,
    'title': title,
    'professor_name': professorName,
    'is_default': isDefault,
    'schedule_text': scheduleText,
  };
}

enum TaskSubmissionStatus { submitted, notSubmitted, unknown }

extension TaskSubmissionStatusValue on TaskSubmissionStatus {
  String get value => switch (this) {
    TaskSubmissionStatus.submitted => 'submitted',
    TaskSubmissionStatus.notSubmitted => 'not_submitted',
    TaskSubmissionStatus.unknown => 'unknown',
  };
}

class TaskView {
  const TaskView({
    required this.courseId,
    required this.courseTitle,
    required this.taskNo,
    required this.submissionStatus,
    this.professorName,
    this.title,
    this.startAt,
    this.dueAt,
    this.reportTitle,
    this.reportHtml,
    this.submissionText,
  });

  final String courseId;
  final String courseTitle;
  final int taskNo;
  final TaskSubmissionStatus submissionStatus;
  final String? professorName;
  final String? title;
  final String? startAt;
  final String? dueAt;
  final String? reportTitle;
  final String? reportHtml;
  final String? submissionText;

  JsonMap toJson() => <String, Object?>{
    'course_id': courseId,
    'course_title': courseTitle,
    'professor_name': professorName,
    'task_no': taskNo,
    'title': title,
    'start_at': startAt,
    'due_at': dueAt,
    'submission_status': submissionStatus.value,
    'report_title': reportTitle,
    'report_html': reportHtml,
    'submission_text': submissionText,
  };
}

class NoticeView {
  const NoticeView({
    required this.courseId,
    required this.courseTitle,
    required this.boardNo,
    required this.hasAttachments,
    required this.fileCount,
    this.title,
    this.authorName,
    this.postedAt,
  });

  final String courseId;
  final String courseTitle;
  final int boardNo;
  final bool hasAttachments;
  final int fileCount;
  final String? title;
  final String? authorName;
  final String? postedAt;

  JsonMap toJson() => <String, Object?>{
    'course_id': courseId,
    'course_title': courseTitle,
    'board_no': boardNo,
    'title': title,
    'author_name': authorName,
    'posted_at': postedAt,
    'has_attachments': hasAttachments,
    'file_count': fileCount,
  };
}

enum ScheduleKind { classSession, calendarEvent }

extension ScheduleKindValue on ScheduleKind {
  String get value => switch (this) {
    ScheduleKind.classSession => 'class_session',
    ScheduleKind.calendarEvent => 'calendar_event',
  };
}

class ScheduleView {
  const ScheduleView({
    required this.kind,
    required this.source,
    required this.title,
    this.courseId,
    this.courseTitle,
    this.professorName,
    this.classroom,
    this.dayOfWeek,
    this.startsAt,
    this.endsAt,
    this.status,
  });

  final ScheduleKind kind;
  final String source;
  final String title;
  final String? courseId;
  final String? courseTitle;
  final String? professorName;
  final String? classroom;
  final String? dayOfWeek;
  final String? startsAt;
  final String? endsAt;
  final String? status;

  JsonMap toJson() => <String, Object?>{
    'kind': kind.value,
    'source': source,
    'title': title,
    'course_id': courseId,
    'course_title': courseTitle,
    'professor_name': professorName,
    'classroom': classroom,
    'day_of_week': dayOfWeek,
    'starts_at': startsAt,
    'ends_at': endsAt,
    'status': status,
  };
}

String prettyJson(Object? value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}
