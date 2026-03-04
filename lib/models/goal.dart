
import 'enums.dart';
import 'goal_target.dart';
import 'log_entry.dart';

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
  List<BucketItem> items;

  BucketList({required this.title, required this.items});

  Map<String, dynamic> toMap() => {
    'title': title,
    'items': items.map((item) => item.toMap()).toList(),
  };

  factory BucketList.fromMap(Map<String, dynamic> map) => BucketList(
    title: map['title'] as String,
    items: (map['items'] as List<dynamic>?)
            ?.map((e) => BucketItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

// ─── Goal ────────────────────────────────────────────────────────────────────

class Goal {
    Goal copyWith({
      String? id,
      String? title,
      GoalMetricType? metricType,
      GoalCategory? category,
      GoalTarget? target,
      List<LogEntry>? logs,
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
  final String id;
  final String title;
  final GoalMetricType metricType;
  final GoalCategory? category;
  final GoalTarget target;
  final List<LogEntry> logs;

  Goal({
    required this.id,
    required this.title,
    required this.metricType,
    this.category,
    required this.target,
    required this.logs,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'],
        title: json['title'],
        metricType: GoalMetricType.values.firstWhere((e) => e.name == json['metricType']),
        category: json['category'] != null
            ? GoalCategory.values.firstWhere((e) => e.name == json['category'])
            : null,
        target: GoalTarget.fromJson(json['target']),
        logs: (json['logs'] as List).map((e) => LogEntry.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'metricType': metricType.name,
        'category': category?.name,
        'target': target.toJson(),
        'logs': logs.map((l) => l.toJson()).toList(),
      };
}
