import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bucket_app/core/result.dart';
import 'package:bucket_app/models/enums.dart';
import 'package:bucket_app/models/goal.dart';
import 'package:bucket_app/models/goal_log.dart';
import 'package:bucket_app/models/goal_target.dart';
import 'package:bucket_app/models/year_plan.dart';
import 'package:bucket_app/storage/app_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── Save & Load Round-Trip ───────────────────────────────────

  group('saveBucketLists / loadAll round-trip', () {
    test('saves and reloads bucket lists correctly', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      final lists = [
        BucketList(title: 'Travel', items: [
          BucketItem(text: 'Paris'),
          BucketItem(text: 'Tokyo', isDone: true),
        ]),
        BucketList(title: 'Books', items: []),
      ];
      final saveResult = await repo.saveBucketLists(lists);
      expect(saveResult, isA<Ok<void>>());

      // Reload with fresh repo (same prefs)
      final repo2 = AppRepository();
      final loadResult = await repo2.loadAll();
      expect(loadResult, isA<Ok<AppData>>());
      final data = (loadResult as Ok<AppData>).data;

      expect(data.bucketLists.length, 2);
      expect(data.bucketLists[0].title, 'Travel');
      expect(data.bucketLists[0].items.length, 2);
      expect(data.bucketLists[0].items[1].isDone, true);
      expect(data.bucketLists[1].title, 'Books');
    });

    test('saves empty list', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      final result = await repo.saveBucketLists([]);
      expect(result, isA<Ok<void>>());
    });
  });

  group('saveYearPlans / loadAll round-trip', () {
    test('saves and reloads year plans with goals and logs', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      final plans = [
        YearPlan(id: 'yp1', year: 2026, goals: [
          Goal(
            id: 'g1',
            title: 'Read 10 books',
            metricType: GoalMetricType.count,
            target: GoalTarget(
              mode: GoalTargetMode.total,
              targetTotalValue: 10.0,
              unit: GoalUnit.books,
            ),
            logs: [
              GoalLog.increment(
                id: 'log_1',
                date: DateTime(2026, 3, 5),
                amount: 2.0,
                note: 'Finished two novels',
              ),
            ],
          ),
        ]),
      ];
      final saveResult = await repo.saveYearPlans(plans);
      expect(saveResult, isA<Ok<void>>());

      final repo2 = AppRepository();
      final loadResult = await repo2.loadAll();
      final data = (loadResult as Ok<AppData>).data;

      expect(data.yearPlans.length, 1);
      expect(data.yearPlans[0].goals.length, 1);
      expect(data.yearPlans[0].goals[0].title, 'Read 10 books');
      expect(data.yearPlans[0].goals[0].logs.length, 1);
      expect(data.yearPlans[0].goals[0].logs[0].value, 2.0);
      expect(data.yearPlans[0].goals[0].logs[0].note, 'Finished two novels');
    });
  });

  // ─── Atomic Write (tmp key cleanup) ───────────────────────────

  group('atomic write', () {
    test('tmp key is removed after successful write', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      await repo.saveBucketLists([BucketList(title: 'X', items: [])]);

      final prefs = await SharedPreferences.getInstance();
      // tmp key should be cleaned up
      expect(prefs.getStringList('bucket_lists_tmp'), isNull);
      // actual key should exist
      expect(prefs.getStringList('bucket_lists'), isNotNull);
    });

    test('orphaned tmp keys are cleaned on loadAll', () async {
      SharedPreferences.setMockInitialValues({
        'storage_version': 2,
        'bucket_lists_tmp': ['orphan'],
        'year_plans_v2_tmp': 'orphan',
      });
      final repo = AppRepository();
      await repo.loadAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('bucket_lists_tmp'), isNull);
      expect(prefs.getString('year_plans_v2_tmp'), isNull);
    });
  });

  // ─── Export / Import ──────────────────────────────────────────

  group('export', () {
    test('produces valid JSON with version and data', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();
      await repo.saveBucketLists([BucketList(title: 'Test', items: [])]);

      final result = await repo.exportToJson();
      expect(result, isA<Ok<String>>());

      final jsonStr = (result as Ok<String>).data;
      final parsed = json.decode(jsonStr) as Map<String, dynamic>;
      expect(parsed['version'], 2);
      expect(parsed['exportedAt'], isNotNull);
      expect(parsed['bucket_lists'], isA<List>());
      expect(parsed['year_plans'], isA<List>());
    });

    test('export with empty data still produces valid JSON', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      final result = await repo.exportToJson();
      expect(result, isA<Ok<String>>());

      final parsed = json.decode((result as Ok<String>).data);
      expect(parsed['bucket_lists'], isEmpty);
      expect(parsed['year_plans'], isEmpty);
    });
  });

  group('import', () {
    test('imports valid backup JSON', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      final backup = json.encode({
        'version': 2,
        'bucket_lists': [
          {'title': 'Imported', 'items': [{'text': 'Item 1', 'isDone': false}]},
        ],
        'year_plans': [
          {
            'id': 'yp_imp',
            'year': 2026,
            'goals': [],
          },
        ],
      });
      final result = await repo.importFromJson(backup);
      expect(result, isA<Ok<void>>());

      // Verify data was written
      final loadResult = await repo.loadAll();
      final data = (loadResult as Ok<AppData>).data;
      expect(data.bucketLists.length, 1);
      expect(data.bucketLists[0].title, 'Imported');
      expect(data.yearPlans.length, 1);
    });

    test('rejects oversized import', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      // Create string larger than 10MB
      final huge = 'x' * (AppRepository.maxImportBytes + 1);
      final result = await repo.importFromJson(huge);

      expect(result, isA<Err<void>>());
      expect((result as Err<void>).message, contains('너무 큽니다'));
    });

    test('rejects invalid JSON', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      final result = await repo.importFromJson('not json');
      expect(result, isA<Err<void>>());
      expect((result as Err<void>).message, contains('올바르지 않습니다'));
    });

    test('rejects wrong structure (array instead of object)', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      final result = await repo.importFromJson('[1,2,3]');
      expect(result, isA<Err<void>>());
    });

    test('import with missing keys defaults to empty lists', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      final result = await repo.importFromJson('{}');
      expect(result, isA<Ok<void>>());

      final loadResult = await repo.loadAll();
      final data = (loadResult as Ok<AppData>).data;
      expect(data.bucketLists, isEmpty);
      expect(data.yearPlans, isEmpty);
    });
  });

  // ─── Export → Import round-trip ───────────────────────────────

  group('export → import round-trip', () {
    test('data survives full export → import cycle', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      // Save some data
      await repo.saveBucketLists([
        BucketList(title: 'Goals', items: [
          BucketItem(text: 'Run marathon'),
          BucketItem(text: 'Learn piano', isDone: true),
        ]),
      ]);
      await repo.saveYearPlans([
        YearPlan(id: 'yp1', year: 2026, goals: [
          Goal(
            id: 'g1',
            title: 'Exercise',
            metricType: GoalMetricType.habit,
            target: GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 5),
            logs: [
              GoalLog.habit(id: 'l1', date: DateTime(2026, 3, 1)),
              GoalLog.habit(id: 'l2', date: DateTime(2026, 3, 2)),
            ],
          ),
        ]),
      ]);

      // Export
      final exportResult = await repo.exportToJson();
      final exported = (exportResult as Ok<String>).data;

      // Clear everything
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo2 = AppRepository();

      // Import
      final importResult = await repo2.importFromJson(exported);
      expect(importResult, isA<Ok<void>>());

      // Verify
      final loadResult = await repo2.loadAll();
      final data = (loadResult as Ok<AppData>).data;

      expect(data.bucketLists.length, 1);
      expect(data.bucketLists[0].items.length, 2);
      expect(data.bucketLists[0].items[1].isDone, true);

      expect(data.yearPlans.length, 1);
      expect(data.yearPlans[0].goals[0].logs.length, 2);
      expect(data.yearPlans[0].goals[0].title, 'Exercise');
    });
  });
}
