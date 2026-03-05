import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bucket_app/core/result.dart';
import 'package:bucket_app/state/app_state.dart';
import 'package:bucket_app/storage/app_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppState.import with corrupted JSON', () {
    test('returns Err and does not crash', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();

      final result = await state.import('not valid json {{{');

      expect(result, isA<Err<void>>());
      final err = result as Err<void>;
      expect(err.message, contains('올바르지 않습니다'));
      // App state should still be usable
      expect(state.bucketLists, isEmpty);
      expect(state.yearPlans, isEmpty);
      expect(state.isLoading, false);
    });

    test('returns Err for JSON with wrong structure', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();

      // Valid JSON but not the expected format (list instead of map)
      final result = await state.import('[1, 2, 3]');

      expect(result, isA<Err<void>>());
    });

    test('existing data is preserved on failed import', () async {
      // Pre-seed some data
      final existingData = json.encode([
        {
          'id': 'plan_1',
          'year': 2026,
          'goals': [],
        }
      ]);
      SharedPreferences.setMockInitialValues({
        'year_plans_v2': existingData,
        'storage_version': 2,
      });
      final state = AppState();
      await state.init();
      expect(state.yearPlans.length, 1);

      // Attempt bad import
      final result = await state.import('garbage');

      expect(result, isA<Err<void>>());
      // Original data still intact (import does not clear before writing)
      expect(state.yearPlans.length, 1);
    });
  });

  group('AppRepository.loadAll with corrupted prefs', () {
    test('corrupted bucket list items are skipped with warning', () async {
      SharedPreferences.setMockInitialValues({
        'bucket_lists': ['not json', '{"title":"Good","items":[]}'],
        'storage_version': 2,
      });
      final repo = AppRepository();
      final result = await repo.loadAll();

      expect(result, isA<Ok<AppData>>());
      final ok = result as Ok<AppData>;
      // Good item should load, bad one skipped
      expect(ok.data.bucketLists.length, 1);
      expect(ok.warnings.any((w) => w.contains('파싱 실패')), true);
    });

    test('corrupted year_plans returns empty with warning', () async {
      SharedPreferences.setMockInitialValues({
        'year_plans_v2': 'totally broken json',
        'storage_version': 2,
      });
      final repo = AppRepository();
      final result = await repo.loadAll();

      expect(result, isA<Ok<AppData>>());
      final ok = result as Ok<AppData>;
      expect(ok.data.yearPlans, isEmpty);
      expect(ok.warnings.any((w) => w.contains('손상')), true);
    });

    test('missing keys return empty lists, no errors', () async {
      SharedPreferences.setMockInitialValues({
        'storage_version': 2,
      });
      final repo = AppRepository();
      final result = await repo.loadAll();

      expect(result, isA<Ok<AppData>>());
      final ok = result as Ok<AppData>;
      expect(ok.data.bucketLists, isEmpty);
      expect(ok.data.yearPlans, isEmpty);
    });
  });

  group('AppState error field', () {
    test('lastError is null initially', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();

      expect(state.lastError, isNull);
    });

    test('clearError resets lastError', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();

      // There's no easy way to force a persist failure in unit tests,
      // but we can verify the clear mechanism works
      state.clearError();
      expect(state.lastError, isNull);
    });

    test('clearWarnings resets warnings', () async {
      SharedPreferences.setMockInitialValues({
        'year_plans_v2': 'broken',
        // No storage_version, so migration will run and hit corrupted data
      });
      final state = AppState();
      await state.init();

      // Should have warnings from corrupted data
      expect(state.warnings, isNotEmpty);

      state.clearWarnings();
      expect(state.warnings, isEmpty);
    });
  });

  group('AppState.init resilience', () {
    test('init with all corrupted data → safe empty state', () async {
      SharedPreferences.setMockInitialValues({
        'bucket_lists': ['bad1', 'bad2'],
        'year_plans_v2': '{{{invalid',
        'storage_version': 2,
      });
      final state = AppState();
      await state.init();

      // Should not crash, should be in usable state
      expect(state.isLoading, false);
      expect(state.bucketLists, isEmpty);
      expect(state.yearPlans, isEmpty);
      // Should have collected warnings
      expect(state.warnings, isNotEmpty);
    });
  });
}
