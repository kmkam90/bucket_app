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
    List<int>? recommendedDays,
    this.targetTotalValue,
    this.unit,
    this.startDate,
    this.endDate,
  })  : assert(
          mode != GoalTargetMode.frequency || (timesPerWeek != null && timesPerWeek > 0),
          'frequency mode requires timesPerWeek > 0',
        ),
        assert(
          mode != GoalTargetMode.total || (targetTotalValue != null && targetTotalValue > 0),
          'total mode requires targetTotalValue > 0',
        ),
        assert(
          recommendedDays == null || recommendedDays.every((d) => d >= 0 && d <= 6),
          'recommendedDays values must be 0–6 (Mon–Sun)',
        ),
        assert(
          startDate == null || endDate == null || !endDate.isBefore(startDate),
          'endDate must not be before startDate',
        ),
        recommendedDays = recommendedDays != null
            ? List<int>.unmodifiable(recommendedDays)
            : null;

  /// Validates and returns a list of user-friendly Korean messages (empty = valid).
  List<String> validate() {
    final issues = <String>[];
    if (mode == GoalTargetMode.frequency) {
      if (timesPerWeek == null || timesPerWeek! <= 0) {
        issues.add('주간 횟수를 1 이상 입력하세요');
      }
    }
    if (mode == GoalTargetMode.total) {
      if (targetTotalValue == null || targetTotalValue! <= 0) {
        issues.add('목표 수치를 0보다 크게 입력하세요');
      }
      if (unit == null) {
        issues.add('목표 단위를 선택하세요');
      }
    }
    if (recommendedDays != null && recommendedDays!.any((d) => d < 0 || d > 6)) {
      issues.add('요일은 0(월)~6(일) 범위여야 합니다');
    }
    if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) {
      issues.add('종료일이 시작일보다 앞설 수 없습니다');
    }
    return issues;
  }

  bool get isValid => validate().isEmpty;

  GoalTarget copyWith({
    GoalTargetMode? mode,
    int? timesPerWeek,
    List<int>? recommendedDays,
    double? targetTotalValue,
    GoalUnit? unit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return GoalTarget(
      mode: mode ?? this.mode,
      timesPerWeek: timesPerWeek ?? this.timesPerWeek,
      recommendedDays: recommendedDays ?? this.recommendedDays,
      targetTotalValue: targetTotalValue ?? this.targetTotalValue,
      unit: unit ?? this.unit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  /// Safe deserialization — provides sensible defaults for corrupted data
  /// to avoid assert failures from external/legacy JSON.
  factory GoalTarget.fromJson(Map<String, dynamic> json) {
    final modeStr = json['mode'] as String?;
    final mode = GoalTargetMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => GoalTargetMode.frequency,
    );

    // Parse raw values
    final timesPerWeek = json['timesPerWeek'] as int?;
    final targetTotalValue = (json['targetTotalValue'] as num?)?.toDouble();

    // Provide safe defaults so asserts never fire on bad data
    final safeTimesPerWeek = mode == GoalTargetMode.frequency
        ? (timesPerWeek != null && timesPerWeek > 0 ? timesPerWeek : 1)
        : timesPerWeek;
    final safeTargetTotalValue = mode == GoalTargetMode.total
        ? (targetTotalValue != null && targetTotalValue > 0 ? targetTotalValue : 1.0)
        : targetTotalValue;

    final rawDays = (json['recommendedDays'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .where((d) => d >= 0 && d <= 6)
        .toList();

    final startDate = json['startDate'] != null
        ? DateTime.tryParse(json['startDate'] as String)
        : null;
    final endDate = json['endDate'] != null
        ? DateTime.tryParse(json['endDate'] as String)
        : null;

    // Ensure endDate >= startDate
    final safeEndDate = (startDate != null && endDate != null && endDate.isBefore(startDate))
        ? startDate
        : endDate;

    return GoalTarget(
      mode: mode,
      timesPerWeek: safeTimesPerWeek,
      recommendedDays: rawDays,
      targetTotalValue: safeTargetTotalValue,
      unit: json['unit'] != null ? goalUnitFromString(json['unit'] as String) : null,
      startDate: startDate,
      endDate: safeEndDate,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'mode': mode.name,
    };
    if (timesPerWeek != null) map['timesPerWeek'] = timesPerWeek;
    if (recommendedDays != null) map['recommendedDays'] = recommendedDays;
    if (targetTotalValue != null) map['targetTotalValue'] = targetTotalValue;
    if (unit != null) map['unit'] = goalUnitToString(unit!);
    if (startDate != null) map['startDate'] = startDate!.toIso8601String();
    if (endDate != null) map['endDate'] = endDate!.toIso8601String();
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalTarget &&
          mode == other.mode &&
          timesPerWeek == other.timesPerWeek &&
          targetTotalValue == other.targetTotalValue &&
          unit == other.unit;

  @override
  int get hashCode => Object.hash(mode, timesPerWeek, targetTotalValue, unit);
}
