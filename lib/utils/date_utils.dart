/// Canonical local-midnight date. Strips time, converts UTC→local first.
DateTime dateOnly(DateTime dt) {
  final local = dt.isUtc ? dt.toLocal() : dt;
  return DateTime(local.year, local.month, local.day);
}

/// Integer key for date: yyyymmdd. Useful for Map/Set lookups.
int dateKey(DateTime dt) => dt.year * 10000 + dt.month * 100 + dt.day;

/// Field-by-field day comparison. DST-safe.
bool sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// DST-safe consecutive day check. Uses Dart's date overflow handling.
bool isNextCalendarDay(DateTime earlier, DateTime later) {
  final next = DateTime(earlier.year, earlier.month, earlier.day + 1);
  return next.year == later.year &&
      next.month == later.month &&
      next.day == later.day;
}

/// ISO week start (Monday midnight).
DateTime startOfIsoWeek(DateTime dt) {
  final d = dateOnly(dt);
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

/// ISO week end (Sunday midnight, inclusive).
DateTime endOfIsoWeek(DateTime dt) {
  final start = startOfIsoWeek(dt);
  return DateTime(start.year, start.month, start.day + 6);
}
