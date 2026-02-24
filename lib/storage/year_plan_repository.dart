import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/year_plan.dart';
import '../models/goal.dart' as goal_model;

class YearPlanRepository {
  static const String storageKey = 'year_plans';

  Future<List<YearPlan>> loadYearPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(storageKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => YearPlan.fromJson(e)).toList();
  }

  Future<void> saveYearPlans(List<YearPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(plans.map((e) => e.toJson()).toList());
    await prefs.setString(storageKey, jsonString);
  }
}

/// 기존 bucket_lists 구조를 새 YearPlan 구조로 변환 (마이그레이션)
/// 기존 bucket_lists: `List<BucketList>` (title, items)
/// 새 구조: `List<YearPlan>` (year, goals[GoalType, logs[LogEntry]])
Future<List<YearPlan>> migrateFromOldBucketLists(List<dynamic> oldBucketLists) async {
  // 예시: oldBucketLists = [{"title": "2026년 버킷리스트", "items": [...]}, ...]
  List<YearPlan> yearPlans = [];
  for (final old in oldBucketLists) {
    final String year = old['title'].replaceAll(RegExp(r'[^0-9]'), '');
    // GoalType별로 분류 (임의 분류: 첫 3개 GoalType에 items 분배)
    final items = old['items'] as List<dynamic>;
    final goalTypes = GoalType.values;
    final goals = <goal_model.Goal>[];
    for (int i = 0; i < goalTypes.length; i++) {
      final logs = <YearLogEntry>[];
      for (int j = i; j < items.length; j += goalTypes.length) {
        final item = items[j];
        logs.add(YearLogEntry(
          text: item['text'] ?? '',
          isDone: item['isDone'] ?? false,
          completedAt: item['completedAt'] != null ? DateTime.tryParse(item['completedAt']) : null,
        ));
      }
      // goals.add(Goal(type: goalTypes[i], logs: logs)); // Remove or refactor if not needed
    }
    yearPlans.add(YearPlan(id: '', year: int.tryParse(year) ?? 0, goals: goals));
  }
  return yearPlans;
}
