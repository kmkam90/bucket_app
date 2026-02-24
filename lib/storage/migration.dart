import '../models/year_plan.dart';
import '../models/goal.dart' as goal_model;
import '../models/goal_target.dart';
import '../models/enums.dart';

/// 기존 bucket_lists -> YearPlan 구조 마이그레이션
/// bucket_lists: [{title: '2026년 버킷리스트', items: [{text, isDone}]}]
/// 정책: 날짜 정보 없으므로 habit 목표만 생성, 로그는 모두 미완료(0)
/// bucket_lists: `List<Map>` -> `List<YearPlan>`
List<YearPlan> migrateFromOldBucketLists(dynamic oldBucketListsRaw) {
  if (oldBucketListsRaw == null) return [];
  try {
    final oldBucketLists = oldBucketListsRaw as List<dynamic>;
    return oldBucketLists.map((old) {
      final yearStr = old['title'] as String? ?? '';
      final year = int.tryParse(RegExp(r'\d{4}').stringMatch(yearStr) ?? '') ?? 0;
      final items = old['items'] as List<dynamic>? ?? [];
      final goals = items.map((item) {
        return goal_model.Goal(
          id: item['text'] ?? '',
          title: item['text'] ?? '',
          metricType: GoalMetricType.habit,
          category: null,
          target: GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 1),
          logs: [],
        );
      }).toList();
      return YearPlan(
        id: yearStr,
        year: year,
        goals: goals,
      );
    }).toList();
  } catch (e) {
    return [];
  }
}

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
