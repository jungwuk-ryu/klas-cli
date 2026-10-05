import 'dart:convert';

import 'package:klas_cli/klas_cli.dart';
import 'package:klas_cli/src/models/cli_models.dart';
import 'package:test/test.dart';

import 'cli_test.dart' show FakeTerminal, FakeKlasService;

const _events = <ScheduleView>[
  ScheduleView(
    kind: ScheduleKind.calendarEvent,
    source: 'monthly_schedule_table',
    title: '[과제] 연습 과제',
    startsAt: '2026-09-25T20:00:00.000',
    endsAt: '2026-10-06T14:59:00.000',
    status: '과제',
  ),
  ScheduleView(
    kind: ScheduleKind.calendarEvent,
    source: 'monthly_schedule_table',
    title: '[학사일정] 학사 행사',
    startsAt: '2026-10-20T00:00:00.000',
    endsAt: '2026-11-02T00:00:00.000',
    status: '학사일정',
  ),
];

FakeKlasService _service() => FakeKlasService(
  scheduleMonthHandler: ({required allowPrompt, year, month}) async {
    expect(year, 2026);
    expect(month, 10);
    return const CommandPayload<List<ScheduleView>>(
      data: _events,
      meta: {'count': 2, 'year': 2026, 'month': 10},
    );
  },
);

void main() {
  test(
    'calendar JSON includes full periods across both month boundaries',
    () async {
      final terminal = FakeTerminal();
      expect(
        await runKlasCli(
          [
            '--format',
            'json',
            'calendar',
            'month',
            '--year',
            '2026',
            '--month',
            '10',
          ],
          terminal: terminal,
          service: _service(),
        ),
        0,
      );
      final result = jsonDecode(terminal.outLines.single) as Map;
      expect(result['ok'], isTrue);
      expect(result['command'], 'calendar month');
      expect(result['data'][0]['starts_at'], _events.first.startsAt);
      expect(result['data'][0]['ends_at'], _events.first.endsAt);
      expect(result['data'][1]['ends_at'], _events.last.endsAt);
      expect(terminal.errLines, isEmpty);
    },
  );

  test('calendar text shows start and end times for each event', () async {
    final terminal = FakeTerminal();
    expect(
      await runKlasCli(
        ['calendar', 'month', '--year', '2026', '--month', '10'],
        terminal: terminal,
        service: _service(),
      ),
      0,
    );
    final text = terminal.outLines.join('\n');
    expect(text, contains('start=2026-09-25T20:00:00.000'));
    expect(text, contains('end=2026-10-06T14:59:00.000'));
    expect(text, contains('end=2026-11-02T00:00:00.000'));
  });

  test('calendar field selection retains requested interval fields', () async {
    final terminal = FakeTerminal();
    expect(
      await runKlasCli(
        [
          '--format',
          'json',
          '--fields',
          'title,starts_at,ends_at',
          'calendar',
          'month',
          '--year',
          '2026',
          '--month',
          '10',
        ],
        terminal: terminal,
        service: _service(),
      ),
      0,
    );
    final rows = jsonDecode(terminal.outLines.single)['data'] as List;
    expect(
      (rows.first as Map).keys,
      unorderedEquals(['title', 'starts_at', 'ends_at']),
    );
    expect(rows.last['ends_at'], _events.last.endsAt);
    expect(terminal.errLines, isEmpty);
  });
}
