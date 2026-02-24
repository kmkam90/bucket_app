import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/year_plan.dart';
import '../models/goal.dart' as goal_model;

import 'migration.dart';

class YearPlanRepository {
  static const String storageKey = 'year_plans_v2';
  static const String didMigrateKey = 'did_migrate_v2';
  static const List<String> legacyKeys = [
    'bucket_lists',
    'legacy_goals',
    'goals',
    // 필요한 legacy 키 추가
  ];

  Future<List<YearPlan>> loadYearPlans() async {
    final prefs = await SharedPreferences.getInstance();
    // 마이그레이션 1회만 수행
    final didMigrate = prefs.getBool(didMigrateKey) ?? false;
    if (!didMigrate) {
      await _tryMigrateLegacyData(prefs);
    }
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

  Future<void> _tryMigrateLegacyData(SharedPreferences prefs) async {
    bool migrated = false;
    List<YearPlan> allPlans = [];
    for (final key in legacyKeys) {
      final raw = prefs.get(key);
      if (raw == null) continue;
      try {
        dynamic decoded;
        if (raw is String) {
          decoded = json.decode(raw);
        } else if (raw is List) {
          decoded = raw;
        } else {
          continue;
        }
        if (key == 'bucket_lists') {
          final plans = migrateFromOldBucketLists(decoded);
          if (plans.isNotEmpty) {
            allPlans.addAll(plans);
            migrated = true;
          }
        } else {
          // 기타 legacy goal 리스트는 1년치 YearPlan으로 묶음
          final goals = migrateOldGoals(decoded);
          if (goals.isNotEmpty) {
            final year = DateTime.now().year;
            allPlans.add(YearPlan(
              id: 'migrated_$key',
              year: year,
              goals: goals,
            ));
            migrated = true;
          }
        }
      } catch (e) {
        // 파싱 실패시 무시
      }
    }
    if (migrated) {
      // 중복 연도 병합(간단히 연도별로 goals 합치기)
      final Map<int, List<goal_model.Goal>> byYear = {};
      for (final plan in allPlans) {
        byYear.putIfAbsent(plan.year, () => []).addAll(plan.goals);
      }
      final merged = byYear.entries.map((e) => YearPlan(
        id: 'merged_${e.key}',
        year: e.key,
        goals: e.value,
      )).toList();
      final jsonString = json.encode(merged.map((e) => e.toJson()).toList());
      await prefs.setString(storageKey, jsonString);
      // legacy 키 삭제 또는 migrated 플래그 저장
      for (final key in legacyKeys) {
        await prefs.remove(key);
      }
    }
    await prefs.setBool(didMigrateKey, true);
  }
}
