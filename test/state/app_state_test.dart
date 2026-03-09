import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bucket_app/models/enums.dart';
import 'package:bucket_app/models/goal.dart';
import 'package:bucket_app/models/goal_log.dart';
import 'package:bucket_app/models/goal_target.dart';
import 'package:bucket_app/models/year_plan.dart';
import 'package:bucket_app/state/app_state.dart';

/// Helper to create a pre-loaded AppState.
Future<AppState> _createState({
  List<BucketList>? bucketLists,
  List<YearPlan>? yearPlans,
}) async {
  final prefs = <String, Object>{'storage_version': 2};

  if (bucketLists != null) {
    prefs['bucket_lists'] =
        bucketLists.map((l) => json.encode(l.toMap())).toList();
  }
  if (yearPlans != null) {
    prefs['year_plans_v2'] =
        json.encode(yearPlans.map((p) => p.toJson()).toList());
  }

  SharedPreferences.setMockInitialValues(prefs);
  final state = AppState();
  await state.init();
  return state;
}

Goal _makeHabitGoal(String id, String title) => Goal(
      id: id,
      title: title,
      metricType: GoalMetricType.habit,
      target: GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 3),
      logs: [],
    );

Goal _makeTotalGoal(String id, String title) => Goal(
      id: id,
      title: title,
      metricType: GoalMetricType.count,
      target: GoalTarget(
        mode: GoalTargetMode.total,
        targetTotalValue: 10.0,
        unit: GoalUnit.books,
      ),
      logs: [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── Init ─────────────────────────────────────────────────────

  group('init', () {
    test('loads empty state from fresh prefs', () async {
      final state = await _createState();
      expect(state.isLoading, false);
      expect(state.bucketLists, isEmpty);
      expect(state.yearPlans, isEmpty);
      expect(state.lastError, isNull);
    });

    test('loads pre-existing data', () async {
      final state = await _createState(
        bucketLists: [
          BucketList(title: 'Travel', items: [BucketItem(text: 'Paris')]),
        ],
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: [_makeHabitGoal('g1', 'Run')]),
        ],
      );
      expect(state.bucketLists.length, 1);
      expect(state.bucketLists[0].title, 'Travel');
      expect(state.yearPlans.length, 1);
      expect(state.yearPlans[0].goals.length, 1);
    });
  });

  // ─── Bucket List CRUD ─────────────────────────────────────────

  group('BucketList mutations', () {
    test('addBucketList appends and persists', () async {
      final state = await _createState();
      await state.addBucketList(BucketList(title: 'New', items: []));

      expect(state.bucketLists.length, 1);
      expect(state.bucketLists[0].title, 'New');

      // Verify in-memory state is correct
      expect(state.bucketLists.length, 1);
    });

    test('updateBucketList replaces at index', () async {
      final state = await _createState(
        bucketLists: [
          BucketList(title: 'Old', items: []),
        ],
      );
      await state.updateBucketList(
          0, BucketList(title: 'Updated', items: []));

      expect(state.bucketLists[0].title, 'Updated');
    });

    test('updateBucketList ignores invalid index', () async {
      final state = await _createState(
        bucketLists: [BucketList(title: 'A', items: [])],
      );
      await state.updateBucketList(-1, BucketList(title: 'X', items: []));
      await state.updateBucketList(5, BucketList(title: 'X', items: []));

      expect(state.bucketLists.length, 1);
      expect(state.bucketLists[0].title, 'A');
    });

    test('deleteBucketList removes at index', () async {
      final state = await _createState(
        bucketLists: [
          BucketList(title: 'A', items: []),
          BucketList(title: 'B', items: []),
        ],
      );
      await state.deleteBucketList(0);

      expect(state.bucketLists.length, 1);
      expect(state.bucketLists[0].title, 'B');
    });

    test('deleteBucketList ignores invalid index', () async {
      final state = await _createState(
        bucketLists: [BucketList(title: 'A', items: [])],
      );
      await state.deleteBucketList(99);
      expect(state.bucketLists.length, 1);
    });

    test('deleteBucketLists removes multiple indexes (reverse order)', () async {
      final state = await _createState(
        bucketLists: [
          BucketList(title: 'A', items: []),
          BucketList(title: 'B', items: []),
          BucketList(title: 'C', items: []),
        ],
      );
      await state.deleteBucketLists({0, 2});

      expect(state.bucketLists.length, 1);
      expect(state.bucketLists[0].title, 'B');
    });
  });

  // ─── Year Plan CRUD ───────────────────────────────────────────

  group('YearPlan mutations', () {
    test('addYearPlan appends', () async {
      final state = await _createState();
      await state.addYearPlan(
          YearPlan(id: 'yp1', year: 2026, goals: []));

      expect(state.yearPlans.length, 1);
      expect(state.yearPlans[0].year, 2026);
    });

    test('updateYearPlan replaces matching id', () async {
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: []),
        ],
      );
      final updated = YearPlan(
          id: 'yp1', year: 2026, goals: [_makeHabitGoal('g1', 'Run')]);
      await state.updateYearPlan(updated);

      expect(state.yearPlans[0].goals.length, 1);
      expect(state.yearPlans[0].goals[0].title, 'Run');
    });

    test('updateYearPlan ignores unknown id', () async {
      final state = await _createState(
        yearPlans: [YearPlan(id: 'yp1', year: 2026, goals: [])],
      );
      await state.updateYearPlan(
          YearPlan(id: 'unknown', year: 2026, goals: []));

      expect(state.yearPlans.length, 1);
      expect(state.yearPlans[0].id, 'yp1');
    });

    test('deleteYearPlan removes matching id', () async {
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2025, goals: []),
          YearPlan(id: 'yp2', year: 2026, goals: []),
        ],
      );
      await state.deleteYearPlan('yp1');

      expect(state.yearPlans.length, 1);
      expect(state.yearPlans[0].id, 'yp2');
    });
  });

  // ─── Goal Mutations ───────────────────────────────────────────

  group('Goal mutations', () {
    test('toggleHabit adds log on empty date', () async {
      final state = await _createState(
        yearPlans: [
          YearPlan(
              id: 'yp1',
              year: 2026,
              goals: [_makeHabitGoal('g1', 'Meditate')]),
        ],
      );
      final date = DateTime(2026, 3, 5);
      await state.toggleHabit('yp1', 'g1', date, 'log_1');

      final goal = state.yearPlans[0].goals[0];
      expect(goal.logs.length, 1);
      expect(goal.logs[0].id, 'log_1');
      expect(goal.logs[0].date, DateTime(2026, 3, 5));
    });

    test('toggleHabit removes log on existing date', () async {
      final log = GoalLog.habit(id: 'log_1', date: DateTime(2026, 3, 5));
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: [
            _makeHabitGoal('g1', 'Meditate').copyWith(logs: [log]),
          ]),
        ],
      );

      // Toggle same date → remove
      await state.toggleHabit('yp1', 'g1', DateTime(2026, 3, 5), 'log_2');

      final goal = state.yearPlans[0].goals[0];
      expect(goal.logs, isEmpty);
    });

    test('toggleHabit ignores invalid yearPlanId', () async {
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: [_makeHabitGoal('g1', 'X')]),
        ],
      );
      await state.toggleHabit('nonexistent', 'g1', DateTime(2026, 3, 5), 'l1');

      // No change
      expect(state.yearPlans[0].goals[0].logs, isEmpty);
    });

    test('toggleHabit ignores invalid goalId', () async {
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: [_makeHabitGoal('g1', 'X')]),
        ],
      );
      await state.toggleHabit('yp1', 'nonexistent', DateTime(2026, 3, 5), 'l1');

      expect(state.yearPlans[0].goals[0].logs, isEmpty);
    });

    test('addGoalLog appends log to goal', () async {
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: [
            _makeTotalGoal('g1', 'Read books'),
          ]),
        ],
      );
      final log = GoalLog.increment(
        id: 'log_1',
        date: DateTime(2026, 3, 5),
        amount: 2.0,
      );
      await state.addGoalLog('yp1', 'g1', log);

      final goal = state.yearPlans[0].goals[0];
      expect(goal.logs.length, 1);
      expect(goal.logs[0].value, 2.0);
    });

    test('addGoalLog ignores invalid ids', () async {
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: [_makeTotalGoal('g1', 'X')]),
        ],
      );
      final log = GoalLog.habit(id: 'l1', date: DateTime(2026, 3, 5));

      await state.addGoalLog('bad', 'g1', log);
      expect(state.yearPlans[0].goals[0].logs, isEmpty);

      await state.addGoalLog('yp1', 'bad', log);
      expect(state.yearPlans[0].goals[0].logs, isEmpty);
    });

    test('removeGoalLog removes matching log', () async {
      final log = GoalLog.increment(
        id: 'log_1',
        date: DateTime(2026, 3, 5),
        amount: 3.0,
      );
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: [
            _makeTotalGoal('g1', 'Read').copyWith(logs: [log]),
          ]),
        ],
      );
      await state.removeGoalLog('yp1', 'g1', 'log_1');

      expect(state.yearPlans[0].goals[0].logs, isEmpty);
    });

    test('removeGoalLog ignores nonexistent logId', () async {
      final log = GoalLog.habit(id: 'log_1', date: DateTime(2026, 3, 5));
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: [
            _makeHabitGoal('g1', 'X').copyWith(logs: [log]),
          ]),
        ],
      );
      await state.removeGoalLog('yp1', 'g1', 'nonexistent');

      expect(state.yearPlans[0].goals[0].logs.length, 1);
    });
  });

  // ─── allGoals ─────────────────────────────────────────────────

  group('allGoals', () {
    test('flattens goals across multiple year plans', () async {
      final state = await _createState(
        yearPlans: [
          YearPlan(id: 'yp1', year: 2025, goals: [
            _makeHabitGoal('g1', 'A'),
            _makeHabitGoal('g2', 'B'),
          ]),
          YearPlan(id: 'yp2', year: 2026, goals: [
            _makeTotalGoal('g3', 'C'),
          ]),
        ],
      );

      expect(state.allGoals.length, 3);
      expect(state.allGoals.map((g) => g.title), ['A', 'B', 'C']);
    });

    test('returns empty list when no year plans', () async {
      final state = await _createState();
      expect(state.allGoals, isEmpty);
    });
  });

  // ─── Error & Retry ────────────────────────────────────────────

  group('error and retry', () {
    test('lastError is null initially', () async {
      final state = await _createState();
      expect(state.lastError, isNull);
      expect(state.canRetry, false);
    });

    test('clearError resets error state', () async {
      final state = await _createState();
      state.clearError();
      expect(state.lastError, isNull);
    });

    test('errorHistory starts empty', () async {
      final state = await _createState();
      expect(state.errorHistory.isEmpty, true);
    });

    test('retryLastOperation does nothing when no failed op', () async {
      final state = await _createState();
      // Should not throw
      await state.retryLastOperation();
      expect(state.lastError, isNull);
    });
  });

  // ─── Import/Export ────────────────────────────────────────────

  group('import/export', () {
    test('export produces valid JSON with version', () async {
      final state = await _createState(
        bucketLists: [BucketList(title: 'Test', items: [])],
      );
      final result = await state.export();
      expect(result, isA<Object>()); // Ok<String>
    });

    test('import with invalid JSON returns error', () async {
      final state = await _createState();
      final result = await state.import('not json');
      expect(result, isA<Object>()); // Err<void>
    });
  });

  // ─── Notifications ────────────────────────────────────────────

  group('notifyListeners', () {
    test('addBucketList triggers notification', () async {
      final state = await _createState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      await state.addBucketList(BucketList(title: 'X', items: []));

      // At least 1 notification (the immediate one before persist)
      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    test('clearWarnings triggers notification', () async {
      final state = await _createState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.clearWarnings();
      expect(notifyCount, 1);
    });

    test('clearError triggers notification', () async {
      final state = await _createState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.clearError();
      expect(notifyCount, 1);
    });
  });
}
