import '../errors/cli_errors.dart';

final RegExp _fieldNamePattern = RegExp(r'^[a-z0-9_]+$');

String validateNoControlChars(
  String value, {
  required String fieldName,
  String? emptyHint,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw CliException(
      code: 'USAGE_ERROR',
      message: '$fieldName must not be empty.',
      exitCode: ExitCodes.usage,
      hint: emptyHint,
    );
  }

  for (final rune in trimmed.runes) {
    if (rune < 0x20 || rune == 0x7f) {
      throw CliException(
        code: 'USAGE_ERROR',
        message:
            '$fieldName contains control characters, which are not allowed.',
        exitCode: ExitCodes.usage,
      );
    }
  }

  return trimmed;
}

String validateCourseSelector(String value) {
  final selector = validateNoControlChars(
    value,
    fieldName: 'course selector',
    emptyHint:
        'Use an exact course id or exact course title from `klas courses list`.',
  );
  if (selector.contains('?') ||
      selector.contains('#') ||
      selector.contains('%')) {
    throw const CliException(
      code: 'USAGE_ERROR',
      message:
          'Course selector must not contain query fragments, anchors, or percent-encoded text.',
      exitCode: ExitCodes.usage,
      hint: 'Pass only the exact course id or exact course title.',
    );
  }
  return selector;
}

List<String> parseSelectedFields(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <String>[];
  }

  final fields = <String>[];
  for (final part in raw.split(',')) {
    final field = validateNoControlChars(
      part,
      fieldName: 'field name',
      emptyHint:
          'Use comma-separated top-level JSON fields such as `title,due_at`.',
    ).toLowerCase();
    if (!_fieldNamePattern.hasMatch(field)) {
      throw const CliException(
        code: 'USAGE_ERROR',
        message:
            'Each field name must use lowercase letters, digits, or underscores only.',
        exitCode: ExitCodes.usage,
        hint:
            'Use comma-separated top-level JSON fields such as `title,due_at`.',
      );
    }
    if (!fields.contains(field)) {
      fields.add(field);
    }
  }
  return fields;
}

Object? selectJsonFields(Object? value, List<String> fields) {
  if (fields.isEmpty || value == null) {
    return value;
  }
  if (value is List<Object?>) {
    return value
        .map((item) => selectJsonFields(item, fields))
        .toList(growable: false);
  }
  if (value is Map<String, Object?>) {
    final filtered = <String, Object?>{};
    for (final field in fields) {
      if (value.containsKey(field)) {
        filtered[field] = value[field];
      }
    }
    return filtered;
  }
  return value;
}

int? validateOptionalIntOption(
  String? value, {
  required String fieldName,
  int? min,
  int? max,
  String? hint,
}) {
  if (value == null) {
    return null;
  }
  final trimmed = validateNoControlChars(
    value,
    fieldName: fieldName,
    emptyHint: hint,
  );
  final parsed = int.tryParse(trimmed);
  if (parsed == null) {
    throw CliException(
      code: 'USAGE_ERROR',
      message: '$fieldName must be an integer.',
      exitCode: ExitCodes.usage,
      hint: hint,
    );
  }
  if (min != null && parsed < min || max != null && parsed > max) {
    throw CliException(
      code: 'USAGE_ERROR',
      message:
          '$fieldName must be between ${min ?? parsed} and ${max ?? parsed}.',
      exitCode: ExitCodes.usage,
      hint: hint,
    );
  }
  return parsed;
}
