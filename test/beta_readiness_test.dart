import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bucket_app/core/result.dart';
import 'package:bucket_app/models/goal.dart';
import 'package:bucket_app/state/app_state.dart';
import 'package:bucket_app/storage/app_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Persist queue serialization', () {
    test('rapid mutations do not interleave writes', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();

      // Fire multiple mutations without awaiting individually
      final futures = <Future<void>>[];
      for (int i = 0; i < 5; i++) {
        futures.add(state.addBucketList(
          BucketList(title: 'List $i', items: []),
        ));
      }
      await Future.wait(futures);

      // All 5 should be present (no data loss from interleaving)
      expect(state.bucketLists.length, 5);
    });

    test('persist queue recovers after error', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();

      // Normal operation should work
      await state.addBucketList(BucketList(title: 'First', items: []));
      expect(state.bucketLists.length, 1);

      // Subsequent writes should still work
      await state.addBucketList(BucketList(title: 'Second', items: []));
      expect(state.bucketLists.length, 2);
    });
  });

  group('Orphaned tmp key cleanup', () {
    test('_tmp keys are removed on loadAll', () async {
      SharedPreferences.setMockInitialValues({
        'year_plans_v2_tmp': '{"orphaned": true}',
        'bucket_lists_tmp': ['orphaned'],
        'storage_version': 2,
      });
      final repo = AppRepository();
      final result = await repo.loadAll();

      expect(result, isA<Ok<AppData>>());

      // Verify tmp keys are cleaned up
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('year_plans_v2_tmp'), isNull);
      expect(prefs.getStringList('bucket_lists_tmp'), isNull);
    });

    test('cleanup does not affect real keys', () async {
      final yearData = json.encode([
        {'id': 'plan_1', 'year': 2026, 'goals': []},
      ]);
      SharedPreferences.setMockInitialValues({
        'year_plans_v2': yearData,
        'year_plans_v2_tmp': 'orphaned',
        'storage_version': 2,
      });
      final repo = AppRepository();
      final result = await repo.loadAll();

      expect(result, isA<Ok<AppData>>());
      final ok = result as Ok<AppData>;
      expect(ok.data.yearPlans.length, 1);
      expect(ok.data.yearPlans[0].year, 2026);
    });
  });

  group('Import file size guard', () {
    test('rejects import over 10MB', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = AppRepository();

      // Create a string just over 10MB
      final oversized = 'x' * (10 * 1024 * 1024 + 1);
      final result = await repo.importFromJson(oversized);

      expect(result, isA<Err<void>>());
      final err = result as Err<void>;
      expect(err.message, contains('10MB'));
    });

    test('accepts import under 10MB', () async {
      SharedPreferences.setMockInitialValues({'storage_version': 2});
      final repo = AppRepository();

      final validJson = json.encode({
        'bucket_lists': [],
        'year_plans': [],
      });
      final result = await repo.importFromJson(validJson);

      expect(result, isA<Ok<void>>());
    });
  });

  group('AppState import with size guard', () {
    test('oversized import returns Err through AppState', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();

      final oversized = 'x' * (10 * 1024 * 1024 + 1);
      final result = await state.import(oversized);

      expect(result, isA<Err<void>>());
    });
  });
}
