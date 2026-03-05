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
