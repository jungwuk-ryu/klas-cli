# Monthly calendar correction

## Goal and scope

Make `klas calendar month --year <year> --month <month>` reproduce KLAS monthly
schedule items with correct start/end dates and times. Keep the existing JSON
envelope and command names; recurring timetable and login behavior are unchanged.

## Implementation

Use the corrected public `KlasMonthlyScheduleTableItem.startsAt` and `endsAt`
fields. Keep valid legacy day-only records usable without overflowing the month.
Include the end timestamp in text output and document the monthly date contract.
Pin the pushed SDK correction for portable source checkouts.

## Surfaces

Update service mapping, text rendering/help, command schema, service and command
tests, README, JSON/agent documentation, the local student skill, and decision log.

## Validation

- `dart run tool/check_all.dart` passed: analysis, all 94 tests, schema/dry-run
  checks, installer contracts, and publish dry-run (zero warnings; the documented
  Git override hint remains).
- `dart compile exe bin/klas.dart -o build/klas.exe` succeeded. The compiled month
  help, schema, and dry-run checks passed.
- Synthetic service and CLI tests cover cross-month periods, compact and
  date-only timestamps, leap days, invalid legacy days, JSON field selection,
  and text output.
- Authenticated source and compiled October 2026 queries returned the same ten
  events as the Chrome monthly calendar with no warnings. Three retain September
  starts, and two retain November ends. Compiled text output shows both dates for
  all ten events. No private schedule fixtures were stored.

## Status

Implementation and validation are complete. The CLI resolves the pushed SDK
calendar correction at `9ababd093d15c486c7ba2f1354e77bbfc6c74702`.

## Security and release constraints

All account calls remain read-only. Never put credentials, private schedule
responses, or screenshots into fixtures or Git. Commit and push the changes;
default-branch merge and pub.dev publication are separate steps.
