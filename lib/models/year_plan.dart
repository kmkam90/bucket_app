import 'package:uuid/uuid.dart';
import 'goal.dart';

class YearPlan {
    YearPlan copyWith({String? id, int? year, List<Goal>? goals}) {
      return YearPlan(
        id: id ?? this.id,
        year: year ?? this.year,
        goals: goals ?? this.goals,
      );
    }
  final String id;
  final int year;
  final List<Goal> goals;

  YearPlan({required this.id, required this.year, required this.goals});

  factory YearPlan.create(int year) => YearPlan(
    id: const Uuid().v4(),
    year: year,
    goals: [],
  );

  factory YearPlan.fromJson(Map<String, dynamic> json) => YearPlan(
    id: json['id'],
    year: json['year'],
    goals: (json['goals'] as List)
    .map((e) => Goal.fromJson(e))
    .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'year': year,
    'goals': goals.map((g) => g.toJson()).toList(),
  };
}

/// Goal 타입 (건강, 자기계발, 여행 등)
enum GoalType { health, selfDevelopment, travel }

String goalTypeToString(GoalType type) {
  switch (type) {
    case GoalType.health:
      return '건강';
    case GoalType.selfDevelopment:
      return '자기계발';
    case GoalType.travel:
      return '여행';
  }
}

GoalType goalTypeFromString(String str) {
  switch (str) {
    case '건강':
      return GoalType.health;
    case '자기계발':
      return GoalType.selfDevelopment;
    case '여행':
      return GoalType.travel;
    default:
      throw ArgumentError('Unknown GoalType: $str');
  }
}


/// 달성/수행 로그
class YearLogEntry {
  final String text;
  final bool isDone;
  final DateTime? completedAt;

  YearLogEntry({required this.text, required this.isDone, this.completedAt});

  factory YearLogEntry.fromJson(Map<String, dynamic> json) => YearLogEntry(
    text: json['text'],
    isDone: json['isDone'],
    completedAt: json['completedAt'] != null
    ? DateTime.parse(json['completedAt'])
    : null,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'isDone': isDone,
    'completedAt': completedAt?.toIso8601String(),
  };
}
