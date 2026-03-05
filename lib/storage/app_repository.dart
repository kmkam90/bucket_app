import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/result.dart';
import '../models/goal.dart';
import '../models/year_plan.dart';
import 'storage_version.dart';

class AppData {
  final List<BucketList> bucketLists;
  final List<YearPlan> yearPlans;
  const AppData({required this.bucketLists, required this.yearPlans});
}

class AppRepository {
  static const _bucketKey = 'bucket_lists';
  static const _yearPlanKey = 'year_plans_v2';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ─── Load All ────────────────────────────────────────────────

  Future<Result<AppData>> loadAll() async {
    try {
      final prefs = await _getPrefs();
      final warnings = <String>[];

      // Run all pending migrations (legacy keys, format conversions, date normalization)
      final migrationWarnings = await StorageMigrator.migrate(prefs);
      warnings.addAll(migrationWarnings);

      // Clean orphaned _tmp keys from interrupted atomic writes
      await _cleanOrphanedTmpKeys(prefs);

      final bucketLists = _loadBucketLists(prefs, warnings);
      final yearPlans = _loadYearPlans(prefs, warnings);

      return Ok(
        AppData(bucketLists: bucketLists, yearPlans: yearPlans),
        warnings: warnings,
      );
    } catch (e) {
      return Err('데이터 로드 실패: $e', error: e);
    }
  }

  List<BucketList> _loadBucketLists(
      SharedPreferences prefs, List<String> warnings) {
    final saved = prefs.getStringList(_bucketKey);
    if (saved == null) return [];
    final result = <BucketList>[];
    for (int i = 0; i < saved.length; i++) {
      try {
        result.add(
            BucketList.fromMap(json.decode(saved[i]) as Map<String, dynamic>));
      } catch (e) {
        warnings.add('버킷리스트 $i번 항목 파싱 실패, 건너뜀');
      }
    }
    return result;
  }

  List<YearPlan> _loadYearPlans(
      SharedPreferences prefs, List<String> warnings) {
    final raw = prefs.getString(_yearPlanKey);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => YearPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      warnings.add('연간 목표 데이터 손상, 초기화됨');
      return [];
    }
  }

  Future<void> _cleanOrphanedTmpKeys(SharedPreferences prefs) async {
    final tmpKeys = prefs.getKeys().where((k) => k.endsWith('_tmp')).toList();
    for (final key in tmpKeys) {
      await prefs.remove(key);
    }
  }

  // ─── Save (atomic: write temp → verify → swap) ─────────────

  Future<Result<void>> saveBucketLists(List<BucketList> lists) async {
    final encoded =
        lists.map((l) => json.encode(l.toMap())).toList(growable: false);
    return _atomicWriteList(_bucketKey, encoded);
  }

  Future<Result<void>> saveYearPlans(List<YearPlan> plans) async {
    final encoded = json.encode(plans.map((p) => p.toJson()).toList());
    return _atomicWriteString(_yearPlanKey, encoded);
  }

  Future<Result<void>> _atomicWriteString(String key, String value) async {
    try {
      final prefs = await _getPrefs();
      final tmpKey = '${key}_tmp';
      await prefs.setString(tmpKey, value);
      if (prefs.getString(tmpKey) == null) {
        return const Err('쓰기 검증 실패');
      }
      await prefs.setString(key, value);
      await prefs.remove(tmpKey);
      return const Ok(null);
    } catch (e) {
      return Err('저장 실패: $e', error: e);
    }
  }

  Future<Result<void>> _atomicWriteList(
      String key, List<String> value) async {
    try {
      final prefs = await _getPrefs();
      final tmpKey = '${key}_tmp';
      await prefs.setStringList(tmpKey, value);
      if (prefs.getStringList(tmpKey) == null) {
        return const Err('쓰기 검증 실패');
      }
      await prefs.setStringList(key, value);
      await prefs.remove(tmpKey);
      return const Ok(null);
    } catch (e) {
      return Err('저장 실패: $e', error: e);
    }
  }

  // ─── Import / Export ────────────────────────────────────────

  Future<Result<String>> exportToJson() async {
    final result = await loadAll();
    switch (result) {
      case Ok(:final data):
        final export = {
          'version': StorageMigrator.currentVersion,
          'exportedAt': DateTime.now().toIso8601String(),
          'bucket_lists': data.bucketLists.map((l) => l.toMap()).toList(),
          'year_plans': data.yearPlans.map((p) => p.toJson()).toList(),
        };
        return Ok(const JsonEncoder.withIndent('  ').convert(export));
      case Err(:final message):
        return Err(message);
    }
  }

  static const int maxImportBytes = 10 * 1024 * 1024; // 10 MB

  Future<Result<void>> importFromJson(String jsonString) async {
    // Guard: reject oversized imports
    if (jsonString.length > maxImportBytes) {
      return const Err('파일이 너무 큽니다 (최대 10MB)');
    }

    // Phase 1: parse everything (no writes yet)
    final List<BucketList> bucketLists;
    final List<YearPlan> yearPlans;
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      bucketLists = (data['bucket_lists'] as List<dynamic>? ?? [])
          .map((e) => BucketList.fromMap(e as Map<String, dynamic>))
          .toList();
      yearPlans = (data['year_plans'] as List<dynamic>? ?? [])
          .map((e) => YearPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return Err('백업 파일이 올바르지 않습니다: $e', error: e);
    }

    // Phase 2: write only after all parsing succeeded
    final r1 = await saveBucketLists(bucketLists);
    if (r1 is Err) return r1;
    final r2 = await saveYearPlans(yearPlans);
    if (r2 is Err) return r2;
    return const Ok(null);
  }
}
