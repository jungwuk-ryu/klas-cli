import '../errors/cli_errors.dart';
import '../models/cli_models.dart';

class CommandOptionSchema {
  const CommandOptionSchema({
    required this.name,
    required this.type,
    required this.description,
    this.required = false,
    this.allowedValues = const <String>[],
    this.global = false,
  });

  final String name;
  final String type;
  final String description;
  final bool required;
  final List<String> allowedValues;
  final bool global;

  JsonMap toJson() => <String, Object?>{
    'name': name,
    'type': type,
    'description': description,
    'required': required,
    'allowed_values': allowedValues,
    'global': global,
  };
}

class CommandArgumentSchema {
  const CommandArgumentSchema({
    required this.name,
    required this.type,
    required this.description,
    this.required = true,
  });

  final String name;
  final String type;
  final String description;
  final bool required;

  JsonMap toJson() => <String, Object?>{
    'name': name,
    'type': type,
    'description': description,
    'required': required,
  };
}

class CommandContract {
  const CommandContract({
    required this.path,
    required this.description,
    required this.outputFields,
    this.options = const <CommandOptionSchema>[],
    this.arguments = const <CommandArgumentSchema>[],
    this.authRequired = false,
    this.supportsDryRun = false,
    this.supportsFields = true,
    this.warningsPossible = false,
    this.notes = const <String>[],
    this.subcommands = const <String>[],
  });

  final String path;
  final String description;
  final List<CommandOptionSchema> options;
  final List<CommandArgumentSchema> arguments;
  final List<String> outputFields;
  final bool authRequired;
  final bool supportsDryRun;
  final bool supportsFields;
  final bool warningsPossible;
  final List<String> notes;
  final List<String> subcommands;

  JsonMap toJson() => <String, Object?>{
    'path': path,
    'description': description,
    'auth_required': authRequired,
    'supports_dry_run': supportsDryRun,
    'supports_fields': supportsFields,
    'warnings_possible': warningsPossible,
    'arguments': arguments.map((item) => item.toJson()).toList(growable: false),
    'options': <Object?>[
      ...globalCommandOptions.map((item) => item.toJson()),
      ...options.map((item) => item.toJson()),
    ],
    'output_fields': outputFields,
    'notes': notes,
    'subcommands': subcommands,
  };
}

const List<CommandOptionSchema> globalCommandOptions = <CommandOptionSchema>[
  CommandOptionSchema(
    name: '--format',
    type: 'string',
    description: 'Output format.',
    allowedValues: <String>['text', 'json'],
    global: true,
  ),
  CommandOptionSchema(
    name: '--fields',
    type: 'string',
    description:
        'Comma-separated top-level JSON data fields to keep in the response.',
    global: true,
  ),
  CommandOptionSchema(
    name: '--dry-run',
    type: 'boolean',
    description: 'Validate local inputs without calling KLAS.',
    global: true,
  ),
];

const Map<String, CommandContract> commandContracts = <String, CommandContract>{
  'schema': CommandContract(
    path: 'schema',
    description:
        'Describe CLI commands, options, and normalized output fields in machine-readable form.',
    supportsFields: true,
    outputFields: <String>['path', 'description', 'commands', 'global_options'],
    arguments: <CommandArgumentSchema>[
      CommandArgumentSchema(
        name: 'command_path',
        type: 'string[]',
        description: 'Optional command path such as `tasks list`.',
        required: false,
      ),
    ],
    notes: <String>[
      'Use `klas schema tasks list --format json` for exact command details.',
    ],
  ),
  'auth': CommandContract(
    path: 'auth',
    description: 'Authenticate and inspect CLI auth readiness.',
    supportsFields: false,
    outputFields: <String>[],
    subcommands: <String>['auth login', 'auth status', 'auth logout'],
  ),
  'auth login': CommandContract(
    path: 'auth login',
    description:
        'Authenticate with KLAS and create durable local reusable auth.',
    supportsFields: true,
    outputFields: <String>[
      'authenticated',
      'credential_source',
      'reusable',
      'checked_at',
    ],
    options: <CommandOptionSchema>[
      CommandOptionSchema(
        name: '--stdin-json',
        type: 'boolean',
        description:
            'Read credentials from stdin as JSON with `id` and `password`.',
      ),
    ],
    notes: <String>[
      'This command writes local auth state, so `--dry-run` is not supported.',
    ],
  ),
  'auth status': CommandContract(
    path: 'auth status',
    description: 'Check whether reusable auth is currently available.',
    supportsDryRun: true,
    supportsFields: true,
    outputFields: <String>[
      'authenticated',
      'reusable',
      'credential_source',
      'checked_at',
      'interactive_available',
      'hint',
    ],
  ),
  'auth logout': CommandContract(
    path: 'auth logout',
    description: 'Clear the durable local auth state managed by this CLI.',
    supportsFields: true,
    outputFields: <String>['message', 'hint'],
    notes: <String>[
      'This command mutates local auth state, so `--dry-run` is not supported.',
    ],
  ),
  'me': CommandContract(
    path: 'me',
    description: 'Read-only commands about the authenticated user.',
    supportsFields: false,
    outputFields: <String>[],
    subcommands: <String>['me profile'],
  ),
  'me profile': CommandContract(
    path: 'me profile',
    description: 'Show the current user profile without exposing student IDs.',
    authRequired: true,
    supportsDryRun: true,
    supportsFields: true,
    outputFields: <String>[
      'authenticated',
      'name',
      'email',
      'mobile_phone',
      'birthday',
    ],
  ),
  'courses': CommandContract(
    path: 'courses',
    description: 'List and inspect course contexts.',
    supportsFields: false,
    outputFields: <String>[],
    subcommands: <String>['courses list', 'courses show'],
  ),
  'courses list': CommandContract(
    path: 'courses list',
    description: 'List all current course contexts.',
    authRequired: true,
    supportsDryRun: true,
    supportsFields: true,
    outputFields: <String>[
      'course_id',
      'term_id',
      'title',
      'professor_name',
      'is_default',
      'schedule_text',
    ],
  ),
  'courses show': CommandContract(
    path: 'courses show',
    description: 'Show one course by exact id or exact title.',
    authRequired: true,
    supportsDryRun: true,
    supportsFields: true,
    outputFields: <String>[
      'course_id',
      'term_id',
      'title',
      'professor_name',
      'is_default',
      'schedule_text',
    ],
    options: <CommandOptionSchema>[
      CommandOptionSchema(
        name: '--course',
        type: 'string',
        description: 'Exact course id or exact course title.',
        required: true,
      ),
    ],
  ),
  'tasks': CommandContract(
    path: 'tasks',
    description: 'List tasks and inspect a single task.',
    supportsFields: false,
    outputFields: <String>[],
    subcommands: <String>['tasks list', 'tasks show'],
  ),
  'tasks list': CommandContract(
    path: 'tasks list',
    description: 'List tasks across courses, with an optional course filter.',
    authRequired: true,
    supportsDryRun: true,
    supportsFields: true,
    warningsPossible: true,
    outputFields: <String>[
      'course_id',
      'course_title',
      'professor_name',
      'task_no',
      'title',
      'start_at',
      'due_at',
      'submission_status',
      'report_title',
      'report_html',
      'submission_text',
    ],
    options: <CommandOptionSchema>[
      CommandOptionSchema(
        name: '--course',
        type: 'string',
        description: 'Exact course id or exact course title.',
      ),
    ],
  ),
  'tasks show': CommandContract(
    path: 'tasks show',
    description: 'Show one task by task number, optionally narrowed by course.',
    authRequired: true,
    supportsDryRun: true,
    supportsFields: true,
    outputFields: <String>[
      'course_id',
      'course_title',
      'professor_name',
      'task_no',
      'title',
      'start_at',
      'due_at',
      'submission_status',
      'report_title',
      'report_html',
      'submission_text',
    ],
    arguments: <CommandArgumentSchema>[
      CommandArgumentSchema(
        name: 'task_no',
        type: 'integer',
        description: 'Task number from `tasks list`.',
      ),
    ],
    options: <CommandOptionSchema>[
      CommandOptionSchema(
        name: '--course',
        type: 'string',
        description: 'Exact course id or exact course title.',
      ),
    ],
  ),
  'notices': CommandContract(
    path: 'notices',
    description: 'List course notices.',
    supportsFields: false,
    outputFields: <String>[],
    subcommands: <String>['notices list'],
  ),
  'notices list': CommandContract(
    path: 'notices list',
    description: 'List notices across courses, with an optional course filter.',
    authRequired: true,
    supportsDryRun: true,
    supportsFields: true,
    warningsPossible: true,
    outputFields: <String>[
      'course_id',
      'course_title',
      'board_no',
      'title',
      'author_name',
      'posted_at',
      'has_attachments',
      'file_count',
    ],
    options: <CommandOptionSchema>[
      CommandOptionSchema(
        name: '--course',
        type: 'string',
        description: 'Exact course id or exact course title.',
      ),
    ],
  ),
  'schedule': CommandContract(
    path: 'schedule',
    description: 'Show today, week, or next schedule items.',
    supportsFields: false,
    outputFields: <String>[],
    subcommands: <String>['schedule today', 'schedule week', 'schedule next'],
  ),
  'schedule today': CommandContract(
    path: 'schedule today',
    description: 'Show schedule items for today.',
    authRequired: true,
    supportsDryRun: true,
    supportsFields: true,
    outputFields: <String>[
      'kind',
      'source',
      'title',
      'course_id',
      'course_title',
      'professor_name',
      'classroom',
      'day_of_week',
      'starts_at',
      'ends_at',
      'status',
    ],
  ),
  'schedule week': CommandContract(
    path: 'schedule week',
    description: 'Show weekly recurring timetable entries.',
    authRequired: true,
    supportsDryRun: true,
    supportsFields: true,
    outputFields: <String>[
      'kind',
      'source',
      'title',
      'course_id',
      'course_title',
      'professor_name',
      'classroom',
      'day_of_week',
      'starts_at',
      'ends_at',
      'status',
    ],
  ),
  'schedule next': CommandContract(
    path: 'schedule next',
    description: 'Show the next upcoming schedule item.',
    authRequired: true,
    supportsDryRun: true,
    supportsFields: true,
    outputFields: <String>[
      'kind',
      'source',
      'title',
      'course_id',
      'course_title',
      'professor_name',
      'classroom',
      'day_of_week',
      'starts_at',
      'ends_at',
      'status',
    ],
  ),
};

CommandContract contractForPath(String path) {
  final contract = commandContracts[path];
  if (contract == null) {
    throw CliException(
      code: 'INTERNAL_ERROR',
      message: 'No command contract was registered for `$path`.',
      exitCode: ExitCodes.software,
    );
  }
  return contract;
}

Object schemaForPath(String? path) {
  if (path == null || path.trim().isEmpty) {
    return <String, Object?>{
      'path': 'klas',
      'description': 'Agent-first KLAS CLI for students and automation.',
      'global_options': globalCommandOptions
          .map((item) => item.toJson())
          .toList(growable: false),
      'commands': commandContracts.values
          .map(
            (contract) => <String, Object?>{
              'path': contract.path,
              'description': contract.description,
              'auth_required': contract.authRequired,
              'supports_dry_run': contract.supportsDryRun,
              'supports_fields': contract.supportsFields,
            },
          )
          .toList(growable: false),
    };
  }

  final normalized = path.trim().replaceAll(RegExp(r'\s+'), ' ');
  final exact = commandContracts[normalized];
  if (exact != null) {
    return exact.toJson();
  }

  final subcommands = commandContracts.values
      .where((contract) => contract.path.startsWith('$normalized '))
      .map((contract) => contract.path)
      .toList(growable: false);
  if (subcommands.isNotEmpty) {
    return <String, Object?>{
      'path': normalized,
      'description': 'Command group.',
      'subcommands': subcommands,
    };
  }

  throw CliException(
    code: 'USAGE_ERROR',
    message: 'No schema entry matched the requested command path.',
    exitCode: ExitCodes.usage,
    hint: 'Run `klas schema --format json` to inspect available command paths.',
  );
}
