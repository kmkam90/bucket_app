import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bucket_app/storage/storage_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── v0 → v1: LogEntry → GoalLog + legacy keys ─────────────

  group('v0→v1 migration', () {
    test('converts legacy LogEntry logs to GoalLog format', () async {
      final v0Data = json.encode([
        {
          'id': 'plan_1',
          'year': 2025,
          'goals': [
            {
              'id': 'goal_1',
              'title': 'Read books',
              'metricType': 'count',
              'target': {'mode': 'total', 'targetTotalValue': 10.0},
              'logs': [
                {'date': '2025-06-15', 'value': 1},
                {'date': '2025-06-16', 'value': 2},
              ],
            }
          ],
        }
      ]);
      SharedPreferences.setMockInitialValues({
        'year_plans_v2': v0Data,
        // No storage_version key → version 0
      });
      final prefs = await SharedPreferences.getInstance();

      final warnings = await StorageMigrator.migrate(prefs);

      // Should have converted logs
      expect(warnings, contains('로그 데이터를 새 형식으로 변환했습니다'));

      // Verify converted data
      final raw = prefs.getString('year_plans_v2')!;
      final plans = json.decode(raw) as List;
      final logs = (plans[0]['goals'] as List)[0]['logs'] as List;
      expect(logs.length, 2);
      expect(logs[0]['id'], startsWith('migrated_'));
      expect(logs[0]['createdAt'], isNotNull);
      expect(logs[0]['value'], 1.0);
      // Version should be set to current
      expect(prefs.getInt(StorageMigrator.versionKey), StorageMigrator.currentVersion);
    });

    test('migrates legacy keys to year_plans_v2', () async {
      final legacyGoals = json.encode([
        {
          'id': 'old_goal',
          'title': 'Run daily',
          'metricType': 'habit',
          'weeklyCount': 5,
        }
      ]);
      SharedPreferences.setMockInitialValues({
        'legacy_goals': legacyGoals,
        // No year_plans_v2, no storage_version
      });
      final prefs = await SharedPreferences.getInstance();

      await StorageMigrator.migrate(prefs);

      // Legacy key should be removed
      expect(prefs.getString('legacy_goals'), isNull);
      // Data should be in year_plans_v2
      expect(prefs.getString('year_plans_v2'), isNotNull);
      // did_migrate_v2 flag should be set
      expect(prefs.getBool('did_migrate_v2'), true);
    });

    test('fresh install — no data, no crash, no warnings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final warnings = await StorageMigrator.migrate(prefs);

      // Only migration warnings would be for actual data changes
      // Fresh install should produce no migration-specific warnings
      expect(warnings.where((w) => w.contains('오류')), isEmpty);
      expect(prefs.getInt(StorageMigrator.versionKey), StorageMigrator.currentVersion);
    });

    test('corrupted JSON in year_plans_v2 → warning, no crash', () async {
      SharedPreferences.setMockInitialValues({
        'year_plans_v2': 'not valid json {{{',
      });
      final prefs = await SharedPreferences.getInstance();

      final warnings = await StorageMigrator.migrate(prefs);

      expect(warnings, isNotEmpty);
      expect(warnings.any((w) => w.contains('오류')), true);
      // Should still set version (migration attempted)
      expect(prefs.getInt(StorageMigrator.versionKey), StorageMigrator.currentVersion);
    });
  });

  // ─── v1 → v2: Date normalization ───────────────────────────

  group('v1→v2 date normalization', () {
    test('normalizes date with time component', () async {
      final v1Data = json.encode([
        {
          'id': 'plan_1',
          'year': 2026,
          'goals': [
            {
              'id': 'goal_1',
              'title': 'Meditate',
              'metricType': 'habit',
              'target': {'mode': 'frequency', 'timesPerWeek': 7},
              'logs': [
                {'id': 'log_1', 'date': '2026-03-05T14:30:00.000', 'value': 1.0, 'createdAt': '2026-03-05T14:30:00.000'},
              ],
            }
          ],
        }
      ]);
      SharedPreferences.setMockInitialValues({
        StorageMigrator.versionKey: 1,
        'year_plans_v2': v1Data,
      });
      final prefs = await SharedPreferences.getInstance();

      final warnings = await StorageMigrator.migrate(prefs);

      expect(warnings, contains('날짜 데이터를 표준 형식으로 변환했습니다'));

      final raw = prefs.getString('year_plans_v2')!;
      final plans = json.decode(raw) as List;
      final logs = (plans[0]['goals'] as List)[0]['logs'] as List;
      expect(logs[0]['date'], '2026-03-05');
    });

    test('normalizes UTC-suffixed date', () async {
      final v1Data = json.encode([
        {
          'id': 'plan_1',
          'year': 2026,
          'goals': [
            {
              'id': 'goal_1',
              'title': 'Exercise',
              'metricType': 'habit',
              'target': {'mode': 'frequency', 'timesPerWeek': 3},
              'logs': [
                {'id': 'log_1', 'date': '2026-03-05T00:00:00.000Z', 'value': 1.0, 'createdAt': '2026-03-05T00:00:00.000Z'},
              ],
            }
          ],
        }
      ]);
      SharedPreferences.setMockInitialValues({
        StorageMigrator.versionKey: 1,
        'year_plans_v2': v1Data,
      });
      final prefs = await SharedPreferences.getInstance();

      await StorageMigrator.migrate(prefs);

      final raw = prefs.getString('year_plans_v2')!;
      final plans = json.decode(raw) as List;
      final logs = (plans[0]['goals'] as List)[0]['logs'] as List;
      // Should be date-only, 10 chars, no T
      final dateStr = logs[0]['date'] as String;
      expect(dateStr.length, 10);
      expect(dateStr.contains('T'), false);
    });

    test('already-normalized dates are unchanged (idempotent)', () async {
      final v1Data = json.encode([
        {
          'id': 'plan_1',
          'year': 2026,
          'goals': [
            {
              'id': 'goal_1',
              'title': 'Read',
              'metricType': 'count',
              'target': {'mode': 'total', 'targetTotalValue': 50.0},
              'logs': [
                {'id': 'log_1', 'date': '2026-03-05', 'value': 5.0, 'createdAt': '2026-03-05T10:00:00.000'},
              ],
            }
          ],
        }
      ]);
      SharedPreferences.setMockInitialValues({
        StorageMigrator.versionKey: 1,
        'year_plans_v2': v1Data,
      });
      final prefs = await SharedPreferences.getInstance();

      final warnings = await StorageMigrator.migrate(prefs);

      // No date normalization warning since data was already clean
      expect(warnings.where((w) => w.contains('날짜')), isEmpty);
    });
  });

  // ─── Future version safety ─────────────────────────────────

  group('future version safety', () {
    test('stored version > current → warning, no data modification', () async {
      final originalData = json.encode([
        {
          'id': 'plan_1',
          'year': 2026,
          'goals': [],
        }
      ]);
      SharedPreferences.setMockInitialValues({
        StorageMigrator.versionKey: 99,
        'year_plans_v2': originalData,
      });
      final prefs = await SharedPreferences.getInstance();

      final warnings = await StorageMigrator.migrate(prefs);

      expect(warnings.length, 1);
      expect(warnings[0], contains('99'));
      expect(warnings[0], contains('${StorageMigrator.currentVersion}'));
      // Version should NOT be bumped down
      expect(prefs.getInt(StorageMigrator.versionKey), 99);
      // Data should be untouched
      expect(prefs.getString('year_plans_v2'), originalData);
    });

    test('stored version == current → no migrations, no warnings', () async {
      SharedPreferences.setMockInitialValues({
        StorageMigrator.versionKey: StorageMigrator.currentVersion,
        'year_plans_v2': json.encode([]),
      });
      final prefs = await SharedPreferences.getInstance();

      final warnings = await StorageMigrator.migrate(prefs);

      expect(warnings, isEmpty);
    });
  });

  // ─── Integration ───────────────────────────────────────────

  group('integration', () {
    test('full v0 → current: data is loadable after migration', () async {
      // Seed v0 data with old-format logs (no id, int value)
      final v0Data = json.encode([
        {
          'id': 'plan_2026',
          'year': 2026,
          'goals': [
            {
              'id': 'goal_run',
              'title': 'Run 5K',
              'metricType': 'habit',
              'target': {'mode': 'frequency', 'timesPerWeek': 3},
              'logs': [
                {'date': '2026-01-15T08:30:00.000', 'value': 1},
                {'date': '2026-01-16T09:00:00.000', 'value': 1},
              ],
            }
          ],
        }
      ]);
      SharedPreferences.setMockInitialValues({
        'year_plans_v2': v0Data,
      });
      final prefs = await SharedPreferences.getInstance();

      await StorageMigrator.migrate(prefs);

      // Verify the data can be parsed
      final raw = prefs.getString('year_plans_v2')!;
      final plans = json.decode(raw) as List;
      final logs = (plans[0]['goals'] as List)[0]['logs'] as List;

      // v0→v1: should have id and createdAt
      expect(logs[0]['id'], isNotNull);
      expect(logs[0]['createdAt'], isNotNull);

      // v1→v2: dates should be normalized
      expect(logs[0]['date'], '2026-01-15');
      expect(logs[1]['date'], '2026-01-16');
    });

    test('version key is set to currentVersion after migration', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await StorageMigrator.migrate(prefs);

      expect(StorageMigrator.getVersion(prefs), StorageMigrator.currentVersion);
    });
  });
}
