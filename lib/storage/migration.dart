import '../models/goal.dart' as goal_model;
import '../models/goal_target.dart';
import '../models/enums.dart';

/// 기존 목표를 frequency/total로 변환
/// - habit(weeklyCount, dailyTarget) → frequency, timesPerWeek=weeklyCount(없으면 1)
/// - count/duration → total, targetTotalValue=totalCount/분 등, unit 지정
/// - unit 기본값: count=books, duration=minutes
/// legacy goals: `List<Map>` -> `List<Goal>`
List<goal_model.Goal> migrateOldGoals(dynamic oldGoalsRaw) {
  if (oldGoalsRaw == null) return [];
  try {
    final oldGoals = oldGoalsRaw as List<dynamic>;
    List<goal_model.Goal> result = [];
    for (final g in oldGoals) {
      final type = g['metricType'] ?? g['type'];
      if (type == 'habit' || type == 0) {
        final timesPerWeek = g['weeklyCount'] ?? 1;
        result.add(goal_model.Goal(
          id: g['id'] ?? '',
          title: g['title'] ?? '',
          metricType: GoalMetricType.habit,
          category: null,
          target: GoalTarget(
            mode: GoalTargetMode.frequency,
            timesPerWeek: timesPerWeek,
            recommendedDays: g['recommendedDays'] != null ? List<int>.from(g['recommendedDays']) : null,
          ),
          logs: [],
        ));
      } else if (type == 'count') {
        final total = g['totalCount'] ?? g['totalCountTarget'] ?? 0;
        result.add(goal_model.Goal(
          id: g['id'] ?? '',
          title: g['title'] ?? '',
          metricType: GoalMetricType.count,
          category: null,
          target: GoalTarget(
            mode: GoalTargetMode.total,
            targetTotalValue: (total is int) ? total.toDouble() : (total as double?),
            unit: GoalUnit.books,
          ),
          logs: [],
        ));
      } else if (type == 'duration') {
        final total = g['totalMinutes'] ?? g['totalCountTarget'] ?? 0;
        result.add(goal_model.Goal(
          id: g['id'] ?? '',
          title: g['title'] ?? '',
          metricType: GoalMetricType.duration,
          category: null,
          target: GoalTarget(
            mode: GoalTargetMode.total,
            targetTotalValue: (total is int) ? total.toDouble() : (total as double?),
            unit: GoalUnit.minutes,
          ),
          logs: [],
        ));
      }
    }
    return result;
  } catch (e) {
    return [];
  }
}
