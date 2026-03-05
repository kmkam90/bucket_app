import 'package:intl/intl.dart';
import '../models/goal.dart';
import '../models/goal_log.dart';
import '../models/enums.dart';
import 'date_utils.dart' as app_dates;

double getFrequencyRate(List<DateTime> checkedDates, int timesPerWeek, int year, {int? month}) {
  final dateSet = checkedDates
      .where((d) => d.year == year && (month == null || d.month == month))
      .map((d) => DateFormat('yyyy-MM-dd').format(d))
      .toSet();
  final weeks = _weeksInPeriod(year, month);
  double sum = 0;
  for (final week in weeks) {
    final weekDates = dateSet.where((ds) {
      final dt = DateTime.parse(ds);
      return !dt.isBefore(week.start) && !dt.isAfter(week.end);
    }).length;
    sum += (weekDates / timesPerWeek).clamp(0, 1);
  }
  if (weeks.isEmpty) return 0.0;
  return (sum / weeks.length) * 100;
}

double getTotalRate(double sum, double target) {
  if (target == 0) return 0.0;
  return (sum / target).clamp(0, 1) * 100;
}

double getMonthlySum(Map<DateTime, double> valueMap, int year, int month) {
  return valueMap.entries
      .where((e) => e.key.year == year && e.key.month == month)
      .fold(0.0, (prev, e) => prev + e.value);
}

double getYearlySum(Map<DateTime, double> valueMap, int year) {
  return valueMap.entries
      .where((e) => e.key.year == year)
      .fold(0.0, (prev, e) => prev + e.value);
}

List<_Week> _weeksInPeriod(int year, [int? month]) {
  DateTime first, last;
  if (month != null) {
    first = DateTime(year, month, 1);
    last = DateTime(year, month + 1, 0);
  } else {
    first = DateTime(year, 1, 1);
    last = DateTime(year, 12, 31);
  }
  // Align to ISO week start (Monday)
  var start = app_dates.startOfIsoWeek(first);
  List<_Week> weeks = [];
  while (!start.isAfter(last)) {
    // Calendar arithmetic for Sunday (inclusive end)
    final end = DateTime(start.year, start.month, start.day + 6);
    weeks.add(_Week(start, end.isAfter(last) ? last : end));
    // Next Monday via calendar arithmetic
    start = DateTime(start.year, start.month, start.day + 7);
  }
  return weeks;
}

class _Week {
  final DateTime start;
  final DateTime end;
  _Week(this.start, this.end);
}

class DashboardStatistics {
  static bool isDoneOnDate(Goal goal, DateTime date) {
    return goal.logs.any((l) =>
        goal.metricType == GoalMetricType.habit &&
        app_dates.sameDate(l.date, date) &&
        l.value == 1);
  }

  static void toggleHabitOnDate(Goal goal, DateTime date) {
    final idx = goal.logs.indexWhere((l) =>
        goal.metricType == GoalMetricType.habit &&
        app_dates.sameDate(l.date, date));
    if (idx >= 0) {
      goal.logs.removeAt(idx);
    } else {
      goal.logs.add(GoalLog.habit(
        id: 'log_${date.millisecondsSinceEpoch}',
        date: date,
      ));
    }
  }

  static int getStreak(Goal goal, DateTime today) {
    return getCurrentStreak(goal);
  }

  /// Current streak: consecutive days ending today or yesterday.
  /// Delegates to GoalProgress when possible.
  static int getCurrentStreak(Goal goal) {
    if (goal.metricType != GoalMetricType.habit) return 0;
    return goal.progress.currentStreak;
  }

  /// Best streak ever achieved.
  static int getBestStreak(Goal goal) {
    if (goal.metricType != GoalMetricType.habit) return 0;
    return goal.progress.bestStreak;
  }
}
