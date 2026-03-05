
import 'enums.dart';
import 'goal_log.dart';
import 'goal_progress.dart';
import 'goal_target.dart';

// ─── BucketList / BucketItem ─────────────────────────────────────────────────

class BucketItem {
  String text;
  bool isDone;
  DateTime? completedAt;

  BucketItem({required this.text, this.isDone = false, this.completedAt});

  Map<String, dynamic> toMap() => {
    'text': text,
    'isDone': isDone,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory BucketItem.fromMap(Map<String, dynamic> map) => BucketItem(
    text: map['text'] as String,
    isDone: map['isDone'] as bool? ?? false,
    completedAt: map['completedAt'] != null
        ? DateTime.tryParse(map['completedAt'] as String)
        : null,
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
