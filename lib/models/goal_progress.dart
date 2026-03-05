import '../utils/date_utils.dart' as app_dates;
import 'enums.dart';
import 'goal_log.dart';
import 'goal_target.dart';

/// Computed progress view for a goal.
///
/// This is a **pure computation layer** — it takes a [GoalTarget] and a list
/// of [GoalLog] entries, then exposes computed properties (percentage, streak,
/// remaining, etc.) without owning or mutating the data.
///
/// Design decisions:
/// - Immutable: all fields are final, logs are unmodifiable.
/// - Mode-aware: frequency and total calculations are separate code paths.
/// - No side effects: adding/removing logs returns a new GoalProgress.
/// - Safe: handles empty logs, zero targets, and mode mismatches gracefully.
class GoalProgress {
  final GoalTarget target;
  final List<GoalLog> logs;

  GoalProgress({
    required this.target,
    List<GoalLog>? logs,
  }) : logs = List<GoalLog>.unmodifiable(
          (logs ?? [])..sort((a, b) => a.date.compareTo(b.date)),
        );

  // ─── Core Computed Properties ───────────────────────────────────────────────

  /// Total accumulated value across all logs.
  double get totalValue => logs.fold(0.0, (sum, log) => sum + log.value);

  /// Completion percentage (0.0–100.0), mode-aware.
  double get completionPercent {
    switch (target.mode) {
      case GoalTargetMode.total:
        if (target.targetTotalValue == null || target.targetTotalValue! <= 0) {
          return 0.0;
        }
        return ((totalValue / target.targetTotalValue!) * 100).clamp(0.0, 100.0);

      case GoalTargetMode.frequency:
        return _frequencyCompletionPercent();
    }
  }

  /// Remaining value to reach the target (for total mode).
  /// Returns 0.0 if already completed or if not in total mode.
  double get remaining {
    if (target.mode != GoalTargetMode.total) return 0.0;
    if (target.targetTotalValue == null) return 0.0;
    return (target.targetTotalValue! - totalValue).clamp(0.0, double.infinity);
  }

  /// Whether the goal is fully completed.
  bool get isCompleted => completionPercent >= 100.0;

  /// Number of unique days with at least one log entry.
  int get activeDays {
    final uniqueDays = logs.map((l) => l.date).toSet();
    return uniqueDays.length;
  }

  // ─── Frequency-Specific ─────────────────────────────────────────────────────

  /// How many times completed in the current ISO week (Mon–Sun).
  int get currentWeekCompletions {
    final now = DateTime.now();
    final weekStart = app_dates.startOfIsoWeek(now);
    final weekEndExclusive = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);

    return logs
        .where((l) => !l.date.isBefore(weekStart) && l.date.isBefore(weekEndExclusive))
        .map((l) => l.date)
        .toSet()
        .length;
  }

  /// Whether this week's frequency target is met.
  bool get isCurrentWeekComplete {
    if (target.mode != GoalTargetMode.frequency) return false;
    if (target.timesPerWeek == null) return false;
    return currentWeekCompletions >= target.timesPerWeek!;
  }

  /// Number of completions still needed this week.
  int get remainingThisWeek {
    if (target.mode != GoalTargetMode.frequency) return 0;
    if (target.timesPerWeek == null) return 0;
    return (target.timesPerWeek! - currentWeekCompletions).clamp(0, target.timesPerWeek!);
  }

  // ─── Streak ─────────────────────────────────────────────────────────────────

  /// Current consecutive-day streak ending today or yesterday.
  int get currentStreak {
    final uniqueDays = logs.map((l) => l.date).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (uniqueDays.isEmpty) return 0;

    final today = app_dates.dateOnly(DateTime.now());
    // Streak must end today or yesterday
    if (!app_dates.sameDate(uniqueDays.first, today) &&
        !app_dates.isNextCalendarDay(uniqueDays.first, today)) {
      return 0;
    }

    int streak = 1;
    for (int i = 1; i < uniqueDays.length; i++) {
      if (app_dates.isNextCalendarDay(uniqueDays[i], uniqueDays[i - 1])) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Best (longest) consecutive-day streak ever.
  int get bestStreak {
    final uniqueDays = logs.map((l) => l.date).toSet().toList()..sort();
    if (uniqueDays.isEmpty) return 0;

    int best = 1, current = 1;
    for (int i = 1; i < uniqueDays.length; i++) {
      if (app_dates.isNextCalendarDay(uniqueDays[i - 1], uniqueDays[i])) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  // ─── Date Queries ───────────────────────────────────────────────────────────

  /// Whether there is a log on the given date.
  bool hasLogOnDate(DateTime date) {
    final d = app_dates.dateOnly(date);
    return logs.any((l) => app_dates.sameDate(l.date, d));
  }

  /// All logs on a specific date.
  List<GoalLog> logsOnDate(DateTime date) {
    final d = app_dates.dateOnly(date);
    return logs.where((l) => app_dates.sameDate(l.date, d)).toList();
  }

  /// Sum of values in a specific month.
  double monthlySum(int year, int month) {
    return logs
        .where((l) => l.date.year == year && l.date.month == month)
        .fold(0.0, (sum, l) => sum + l.value);
  }

  /// Sum of values in a specific year.
  double yearlySum(int year) {
    return logs
        .where((l) => l.date.year == year)
        .fold(0.0, (sum, l) => sum + l.value);
  }

  // ─── Immutable Updates ──────────────────────────────────────────────────────

  /// Returns a new GoalProgress with the log appended.
  GoalProgress addLog(GoalLog log) {
    return GoalProgress(
      target: target,
      logs: [...logs, log],
    );
  }

  /// Returns a new GoalProgress with the log removed by id.
  GoalProgress removeLog(String logId) {
    return GoalProgress(
      target: target,
      logs: logs.where((l) => l.id != logId).toList(),
    );
  }

  /// Returns a new GoalProgress with the log replaced by id.
  GoalProgress updateLog(String logId, GoalLog updated) {
    return GoalProgress(
      target: target,
      logs: logs.map((l) => l.id == logId ? updated : l).toList(),
    );
  }

  /// Toggle a habit completion on a date.
  /// If a log exists on that date, removes it; otherwise adds one.
  GoalProgress toggleDate(DateTime date, {required String Function() generateId}) {
    final existing = logsOnDate(date);
    if (existing.isNotEmpty) {
      final ids = existing.map((l) => l.id).toSet();
      return GoalProgress(
        target: target,
        logs: logs.where((l) => !ids.contains(l.id)).toList(),
      );
    } else {
      return addLog(GoalLog.habit(id: generateId(), date: date));
    }
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  factory GoalProgress.fromJson(Map<String, dynamic> json) {
    final target = GoalTarget.fromJson(
      json['target'] as Map<String, dynamic>? ?? {'mode': 'frequency'},
    );

    final rawLogs = json['logs'] as List<dynamic>?;
    final logs = rawLogs?.map((e) {
      final map = e as Map<String, dynamic>;
      // Detect legacy LogEntry format (has 'value' as int, no 'id')
      if (!map.containsKey('id')) {
        return GoalLog.fromLegacyJson(map);
      }
      return GoalLog.fromJson(map);
    }).toList();

    return GoalProgress(target: target, logs: logs);
  }

  Map<String, dynamic> toJson() => {
        'target': target.toJson(),
        'logs': logs.map((l) => l.toJson()).toList(),
      };

  // ─── Equality ───────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalProgress &&
          target == other.target &&
          logs.length == other.logs.length &&
          _logsEqual(other.logs);

  bool _logsEqual(List<GoalLog> other) {
    for (int i = 0; i < logs.length; i++) {
      if (logs[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(target, logs.length);

  @override
  String toString() =>
      'GoalProgress(mode: ${target.mode.name}, logs: ${logs.length}, '
      'completion: ${completionPercent.toStringAsFixed(1)}%)';

  // ─── Private Helpers ────────────────────────────────────────────────────────

  /// Frequency completion: average weekly score across elapsed weeks.
  /// Weekly score = min(checkedDays / timesPerWeek, 1.0).
  /// Result = average of weekly scores * 100.
  double _frequencyCompletionPercent() {
    if (target.timesPerWeek == null || target.timesPerWeek! <= 0) return 0.0;
    if (logs.isEmpty) return 0.0;

    final start = target.startDate ?? logs.first.date;
    final end = app_dates.dateOnly(target.endDate ?? DateTime.now());

    // Build week boundaries (ISO weeks, Mon–Sun)
    var weekStart = app_dates.startOfIsoWeek(start);

    int totalWeeks = 0;
    double scoreSum = 0.0;

    while (!weekStart.isAfter(end)) {
      // Calendar arithmetic: next Monday = current Monday + 7 days
      final weekEndExclusive = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
      final daysInWeek = logs
          .where((l) =>
              !l.date.isBefore(weekStart) && l.date.isBefore(weekEndExclusive))
          .map((l) => l.date)
          .toSet()
          .length;

      totalWeeks++;
      scoreSum += (daysInWeek / target.timesPerWeek!).clamp(0.0, 1.0);

      weekStart = weekEndExclusive;
    }

    if (totalWeeks == 0) return 0.0;
    return ((scoreSum / totalWeeks) * 100).clamp(0.0, 100.0);
  }
}
