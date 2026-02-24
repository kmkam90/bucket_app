import 'enums.dart';


class GoalTarget {
  final GoalTargetMode mode;
  // frequency
  final int? timesPerWeek;
  final List<int>? recommendedDays;
  // total
  final double? targetTotalValue;
  final GoalUnit? unit;
  // 기간(선택)
  final DateTime? startDate;
  final DateTime? endDate;

  GoalTarget({
    required this.mode,
    this.timesPerWeek,
    this.recommendedDays,
    this.targetTotalValue,
    this.unit,
    this.startDate,
    this.endDate,
  });

  factory GoalTarget.fromJson(Map<String, dynamic> json) => GoalTarget(
        mode: GoalTargetMode.values.firstWhere((e) => e.name == json['mode']),
        timesPerWeek: json['timesPerWeek'],
        recommendedDays: (json['recommendedDays'] as List?)?.map((e) => e as int).toList(),
        targetTotalValue: (json['targetTotalValue'] as num?)?.toDouble(),
        unit: json['unit'] != null ? goalUnitFromString(json['unit']) : null,
        startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
        endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'timesPerWeek': timesPerWeek,
        'recommendedDays': recommendedDays,
        'targetTotalValue': targetTotalValue,
        'unit': unit != null ? goalUnitToString(unit!) : null,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };
}
