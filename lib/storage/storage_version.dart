import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/goal.dart' as goal_model;
import '../models/year_plan.dart';
import '../utils/date_utils.dart' as app_dates;
import 'migration.dart';

/// Sequential storage migration pipeline.
///
/// Every schema change increments [currentVersion]. On app start, [migrate]
/// runs all pending steps in order (v0→v1→v2→...). Steps are idempotent —
/// re-running a completed step is a no-op.
///
/// Version history:
///   0 — initial (no version key, old LogEntry format, legacy keys)
///   1 — GoalLog format (id, double value, note, createdAt) + legacy key consolidation
///   2 — Date normalization (all dates stored as YYYY-MM-DD, no time/UTC suffix)
class StorageMigrator {
  static const int currentVersion = 2;
  static const String versionKey = 'storage_version';
  static const String _yearPlanKey = 'year_plans_v2';
  static const String _didMigrateKey = 'did_migrate_v2';
  static const List<String> _legacyKeys = ['legacy_goals', 'goals'];

  /// Run all pending migrations. Returns list of warnings.
  static Future<List<String>> migrate(SharedPreferences prefs) async {
    final version = prefs.getInt(versionKey) ?? 0;
    final warnings = <String>[];

    // Future version safety: don't touch data from a newer app version
    if (version > currentVersion) {
      warnings.add(
        '저장된 데이터 버전($version)이 앱 버전($currentVersion)보다 높습니다. '
        '일부 데이터가 호환되지 않을 수 있습니다.',
      );
      return warnings;
    }

    if (version < 1) {
      await _migrateV0toV1(prefs, warnings);
    }
    if (version < 2) {
      await _migrateV1toV2(prefs, warnings);
    }

    // Future migrations go here:
    // if (version < 3) await _migrateV2toV3(prefs, warnings);

    await prefs.setInt(versionKey, currentVersion);
    return warnings;
  }

  /// Returns current stored version (for diagnostics).
  static int getVersion(SharedPreferences prefs) {
    return prefs.getInt(versionKey) ?? 0;
  }

  // ─── v0 → v1 ──────────────────────────────────────────────────────────────

  /// Consolidates two migration tasks:
  /// 1. Legacy key migration: `legacy_goals`/`goals` → `year_plans_v2`
  /// 2. LogEntry → GoalLog format conversion (add id, createdAt, double value)
  static Future<void> _migrateV0toV1(
      SharedPreferences prefs, List<String> warnings) async {
    // Part 1: Legacy key migration (previously in AppRepository._runMigrationOnce)
    await _migrateLegacyKeys(prefs, warnings);

    // Part 2: LogEntry → GoalLog format conversion
    await _convertLogEntryToGoalLog(prefs, warnings);
  }

  static Future<void> _migrateLegacyKeys(
      SharedPreferences prefs, List<String> warnings) async {
    final didMigrate = prefs.getBool(_didMigrateKey) ?? false;
    if (didMigrate) return;

    bool migrated = false;
    List<YearPlan> allPlans = [];
    for (final key in _legacyKeys) {
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
        final goals = migrateOldGoals(decoded);
        if (goals.isNotEmpty) {
          final year = DateTime.now().year;
          allPlans.add(
              YearPlan(id: 'migrated_$key', year: year, goals: goals));
          migrated = true;
        }
      } catch (e) {
        warnings.add('레거시 키 "$key" 마이그레이션 실패');
      }
    }

    if (migrated) {
      final Map<int, List<goal_model.Goal>> byYear = {};
      for (final plan in allPlans) {
        byYear.putIfAbsent(plan.year, () => []).addAll(plan.goals);
      }
      final merged = byYear.entries
          .map((e) =>
              YearPlan(id: 'merged_${e.key}', year: e.key, goals: e.value))
          .toList();
      final jsonString =
          json.encode(merged.map((e) => e.toJson()).toList());
      await prefs.setString(_yearPlanKey, jsonString);
      for (final key in _legacyKeys) {
        await prefs.remove(key);
      }
    }
    await prefs.setBool(_didMigrateKey, true);
  }

  static Future<void> _convertLogEntryToGoalLog(
      SharedPreferences prefs, List<String> warnings) async {
    final raw = prefs.getString(_yearPlanKey);
    if (raw == null) return;

    try {
      final List<dynamic> plans = json.decode(raw);
      bool changed = false;

      for (final plan in plans) {
        final goals = plan['goals'] as List<dynamic>? ?? [];
        for (final goal in goals) {
          final logs = goal['logs'] as List<dynamic>? ?? [];
          final updatedLogs = <Map<String, dynamic>>[];

          for (int i = 0; i < logs.length; i++) {
            final log = logs[i] as Map<String, dynamic>;
            if (!log.containsKey('id')) {
              final dateStr = log['date'] as String? ?? '';
              final value = (log['value'] as num?)?.toDouble() ?? 0.0;
              final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
              final normalized = app_dates.dateOnly(parsed);
              updatedLogs.add({
                'id': 'migrated_${parsed.millisecondsSinceEpoch}_$i',
                'date': _dateToString(normalized),
                'value': value,
                'createdAt': parsed.toIso8601String(),
              });
              changed = true;
            } else {
              updatedLogs.add(log);
            }
          }
          goal['logs'] = updatedLogs;
        }
      }

      if (changed) {
        await prefs.setString(_yearPlanKey, json.encode(plans));
        warnings.add('로그 데이터를 새 형식으로 변환했습니다');
      }
    } catch (e) {
      warnings.add('로그 마이그레이션 중 오류 발생: $e');
    }
  }

  // ─── v1 → v2 ──────────────────────────────────────────────────────────────

  /// Normalize all stored log dates to date-only format (YYYY-MM-DD).
  /// Data written before Commit 9 may contain time components or UTC suffixes.
  static Future<void> _migrateV1toV2(
      SharedPreferences prefs, List<String> warnings) async {
    final raw = prefs.getString(_yearPlanKey);
    if (raw == null) return;

    try {
      final List<dynamic> plans = json.decode(raw);
      bool changed = false;

      for (final plan in plans) {
        final goals = plan['goals'] as List<dynamic>? ?? [];
        for (final goal in goals) {
          final logs = goal['logs'] as List<dynamic>? ?? [];
          for (final log in logs) {
            if (log is! Map<String, dynamic>) continue;
            final dateStr = log['date'] as String?;
            if (dateStr == null) continue;

            // Already normalized (exactly YYYY-MM-DD, 10 chars, no T)
            if (dateStr.length == 10 && !dateStr.contains('T')) continue;

            final parsed = DateTime.tryParse(dateStr);
            if (parsed == null) continue;

            final normalized = app_dates.dateOnly(parsed);
            log['date'] = _dateToString(normalized);
            changed = true;
          }
        }
      }

      if (changed) {
        await prefs.setString(_yearPlanKey, json.encode(plans));
        warnings.add('날짜 데이터를 표준 형식으로 변환했습니다');
      }
    } catch (e) {
      warnings.add('날짜 정규화 중 오류 발생: $e');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _dateToString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
