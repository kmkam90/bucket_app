
import 'enums.dart';
import 'goal_log.dart';
import 'goal_progress.dart';
import 'goal_target.dart';

// ─── BucketList / BucketItem ─────────────────────────────────────────────────

class BucketItem {
  String text;
  bool isDone;
  DateTime? completedAt;
  DateTime? deadline;
  BucketItemType goalType;
  int targetValue;
  int currentValue;
  GoalTargetMode targetMode;
  int timesPerWeek;
  String unit;
  List<String> completedDates; // ISO date strings for frequency tracking

  BucketItem({
    required this.text,
    this.isDone = false,
    this.completedAt,
    this.deadline,
    this.goalType = BucketItemType.check,
    this.targetValue = 0,
    this.currentValue = 0,
    this.targetMode = GoalTargetMode.total,
    this.timesPerWeek = 3,
    this.unit = '',
    List<String>? completedDates,
  }) : completedDates = completedDates ?? [];

  double get progressRate {
    if (goalType == BucketItemType.check) return isDone ? 1.0 : 0.0;
    if (targetMode == GoalTargetMode.frequency) {
      return _weeklyCompletionRate;
    }
    if (targetValue <= 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  bool get isCompleted {
    if (goalType == BucketItemType.check) return isDone;
    if (targetMode == GoalTargetMode.frequency) return _weeklyCompletionRate >= 1.0;
    return targetValue > 0 && currentValue >= targetValue;
  }

  /// This week's completion rate for frequency mode
  double get _weeklyCompletionRate {
    if (timesPerWeek <= 0) return 0.0;
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final weekStart = DateTime(now.year, now.month, now.day - (weekday - 1));
    int count = 0;
    for (final ds in completedDates) {
      final d = DateTime.tryParse(ds);
      if (d != null && !d.isBefore(weekStart) && d.isBefore(weekStart.add(const Duration(days: 7)))) {
        count++;
      }
    }
    return (count / timesPerWeek).clamp(0.0, 1.0);
  }

  /// Monthly completion count
  int monthlyCompletionCount(int year, int month) {
    int count = 0;
    for (final ds in completedDates) {
      final d = DateTime.tryParse(ds);
      if (d != null && d.year == year && d.month == month) count++;
    }
    return count;
  }

  /// Yearly completion count
  int yearlyCompletionCount(int year) {
    int count = 0;
    for (final ds in completedDates) {
      final d = DateTime.tryParse(ds);
      if (d != null && d.year == year) count++;
    }
    return count;
  }

  /// Monthly achievement rate for frequency mode
  double monthlyAchievementRate(int year, int month) {
    if (targetMode != GoalTargetMode.frequency || timesPerWeek <= 0) return 0.0;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final weeksInMonth = daysInMonth / 7.0;
    final target = (timesPerWeek * weeksInMonth).round();
    if (target <= 0) return 0.0;
    return (monthlyCompletionCount(year, month) / target).clamp(0.0, 1.0);
  }

  /// Yearly achievement rate for frequency mode
  double yearlyAchievementRate(int year) {
    if (targetMode != GoalTargetMode.frequency || timesPerWeek <= 0) return 0.0;
    final totalWeeks = 52;
    final target = timesPerWeek * totalWeeks;
    if (target <= 0) return 0.0;
    return (yearlyCompletionCount(year) / target).clamp(0.0, 1.0);
  }

  /// Toggle completion for a specific date (frequency mode)
  bool toggleDate(DateTime date) {
    final ds = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (completedDates.contains(ds)) {
      completedDates.remove(ds);
      return false;
    } else {
      completedDates.add(ds);
      return true;
    }
  }

  /// Check if a date is completed
  bool isDateCompleted(DateTime date) {
    final ds = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return completedDates.contains(ds);
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    'isDone': isDone,
    'completedAt': completedAt?.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'goalType': goalType.name,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'targetMode': targetMode.name,
    'timesPerWeek': timesPerWeek,
    'unit': unit,
    'completedDates': completedDates,
  };

  factory BucketItem.fromMap(Map<String, dynamic> map) => BucketItem(
    text: map['text'] as String,
    isDone: map['isDone'] as bool? ?? false,
    completedAt: map['completedAt'] != null
        ? DateTime.tryParse(map['completedAt'] as String)
        : null,
    deadline: map['deadline'] != null
        ? DateTime.tryParse(map['deadline'] as String)
        : null,
    goalType: map['goalType'] != null
        ? BucketItemType.values.firstWhere(
            (e) => e.name == map['goalType'],
            orElse: () => BucketItemType.check,
          )
        : BucketItemType.check,
    targetValue: map['targetValue'] as int? ?? 0,
    currentValue: map['currentValue'] as int? ?? 0,
    targetMode: map['targetMode'] != null
        ? GoalTargetMode.values.firstWhere(
            (e) => e.name == map['targetMode'],
            orElse: () => GoalTargetMode.total,
          )
        : GoalTargetMode.total,
    timesPerWeek: map['timesPerWeek'] as int? ?? 3,
    unit: map['unit'] as String? ?? '',
    completedDates: (map['completedDates'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
  );
}

class BucketList {
  String title;
  GoalCategory? category;
  List<BucketItem> items;

  BucketList({required this.title, this.category, required this.items});

  Map<String, dynamic> toMap() => {
    'title': title,
    'category': category?.name,
    'items': items.map((item) => item.toMap()).toList(),
  };

  factory BucketList.fromMap(Map<String, dynamic> map) => BucketList(
    title: map['title'] as String,
    category: map['category'] != null
        ? GoalCategory.values.firstWhere(
            (e) => e.name == map['category'],
            orElse: () => GoalCategory.etc,
          )
        : null,
    items: (map['items'] as List<dynamic>?)
            ?.map((e) => BucketItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

// ─── Goal ────────────────────────────────────────────────────────────────────

class Goal {
  final String id;
  final String title;
  final GoalMetricType metricType;
  final GoalCategory? category;
  final GoalTarget target;
  final List<GoalLog> logs;

  Goal({
    required this.id,
    required this.title,
    required this.metricType,
    this.category,
    required this.target,
    required this.logs,
  });

  /// Computed progress view — recalculated on access.
  GoalProgress get progress => GoalProgress(target: target, logs: logs);

  Goal copyWith({
    String? id,
    String? title,
    GoalMetricType? metricType,
    GoalCategory? category,
    GoalTarget? target,
    List<GoalLog>? logs,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      metricType: metricType ?? this.metricType,
      category: category ?? this.category,
      target: target ?? this.target,
      logs: logs ?? this.logs,
    );
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['logs'] as List<dynamic>? ?? [];
    final logs = rawLogs.map((e) {
      final map = e as Map<String, dynamic>;
      // Backward-compatible: detect legacy LogEntry (no 'id' field)
      if (!map.containsKey('id')) {
        return GoalLog.fromLegacyJson(map);
      }
      return GoalLog.fromJson(map);
    }).toList();

    return Goal(
      id: json['id'],
      title: json['title'],
      metricType: GoalMetricType.values.firstWhere(
        (e) => e.name == json['metricType'],
        orElse: () => GoalMetricType.habit,
      ),
      category: json['category'] != null
          ? GoalCategory.values.firstWhere(
              (e) => e.name == json['category'],
              orElse: () => GoalCategory.etc,
            )
          : null,
      target: GoalTarget.fromJson(json['target']),
      logs: logs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'metricType': metricType.name,
        'category': category?.name,
        'target': target.toJson(),
        'logs': logs.map((l) => l.toJson()).toList(),
      };
}
