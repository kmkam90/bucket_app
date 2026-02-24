import 'package:intl/intl.dart';
import '../models/goal.dart';
import '../models/log_entry.dart';
import '../models/enums.dart';
import 'package:flutter/material.dart' show DateUtils;

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
  first = first.subtract(Duration(days: (first.weekday - 1) % 7));
  List<_Week> weeks = [];
  DateTime start = first;
  while (start.isBefore(last) || start.isAtSameMomentAs(last)) {
    final end = start.add(const Duration(days: 6));
    weeks.add(_Week(start, end.isAfter(last) ? last : end));
    start = end.add(const Duration(days: 1));
  }
  return weeks;
}

class _Week {
  final DateTime start;
  final DateTime end;
  _Week(this.start, this.end);
}
// ...existing code...

class DashboardStatistics {
  static bool isDoneOnDate(Goal goal, DateTime date) {
    return goal.logs.any((l) => goal.metricType == GoalMetricType.habit && DateUtils.isSameDay(l.date, date) && l.value == 1);
  }

  static void toggleHabitOnDate(Goal goal, DateTime date) {
    final idx = goal.logs.indexWhere((l) => goal.metricType == GoalMetricType.habit && DateUtils.isSameDay(l.date, date));
    if (idx >= 0) {
      goal.logs.removeAt(idx);
    } else {
      goal.logs.add(LogEntry(date: date, value: 1));
    }
  }

  static int getStreak(Goal goal, DateTime today) {
    final logs = goal.logs.where((l) => goal.metricType == GoalMetricType.habit && l.value == 1).toList();
    if (logs.isEmpty) return 0;
    logs.sort((a, b) => b.date.compareTo(a.date));
    int streak = 0;
    DateTime? prev = today;
    for (final log in logs) {
      if (prev == null) {
        prev = log.date;
        streak = 1;
      } else {
        if (prev.difference(log.date).inDays == 1) {
          streak++;
          prev = log.date;
        } else {
          break;
        }
      }
    }
    return streak;
  }

// ...existing code...
}
