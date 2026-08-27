/// A calendar day with no time-of-day or timezone component, formatted as
/// `YYYY-MM-DD`.
///
/// Why this exists (§28 of the design brief): a transaction's `occurred_at`
/// needs both an exact instant (for stable chronological ordering within a
/// day, and for future sync) and a *fixed* calendar day for monthly
/// reporting. If reporting instead converted a stored UTC instant to the
/// device's *current* timezone at query time, a transaction entered at
/// 11pm local time could land in UTC on the next calendar day, and a user
/// who travels (or whose OS timezone changes) would watch old transactions
/// silently jump between months. Capturing [LocalDate] once, at entry
/// time, and never re-deriving it from the UTC instant, makes the month a
/// transaction is reported in permanent.
extension type const LocalDate._(String isoDate) {
  factory LocalDate.fromDateTime(DateTime dateTime) {
    final y = dateTime.year.toString().padLeft(4, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return LocalDate._('$y-$m-$d');
  }

  factory LocalDate.today() => LocalDate.fromDateTime(DateTime.now());

  factory LocalDate.parse(String isoDate) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(isoDate)) {
      throw FormatException('Not a YYYY-MM-DD date: $isoDate');
    }
    return LocalDate._(isoDate);
  }

  String get value => isoDate;

  /// `YYYY-MM`, for grouping transactions into monthly reports.
  String get monthKey => isoDate.substring(0, 7);

  int get year => int.parse(isoDate.substring(0, 4));
  int get month => int.parse(isoDate.substring(5, 7));
  int get day => int.parse(isoDate.substring(8, 10));

  DateTime toDateTime() => DateTime(year, month, day);
}

/// An inclusive [start, end] range of calendar days, used for date-range
/// transaction queries and monthly reports (start/end of a month).
class LocalDateRange {
  final LocalDate start;
  final LocalDate end;
  const LocalDateRange({required this.start, required this.end});

  factory LocalDateRange.forMonth(int year, int month) {
    final start = LocalDate.fromDateTime(DateTime(year, month, 1));
    final end = LocalDate.fromDateTime(DateTime(year, month + 1, 0));
    return LocalDateRange(start: start, end: end);
  }

  factory LocalDateRange.forMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    return LocalDateRange.forMonth(int.parse(parts[0]), int.parse(parts[1]));
  }
}

/// Formats the current instant as UTC epoch milliseconds, the storage
/// representation for every `created_at`/`updated_at`/`occurred_at` column.
int utcNowMillis() => DateTime.now().toUtc().millisecondsSinceEpoch;

int toUtcMillis(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch;

DateTime fromUtcMillis(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
