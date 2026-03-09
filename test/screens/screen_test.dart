import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bucket_app/main.dart';
import 'package:bucket_app/models/enums.dart';
import 'package:bucket_app/models/goal.dart';
import 'package:bucket_app/models/goal_log.dart';
import 'package:bucket_app/models/goal_target.dart';
import 'package:bucket_app/models/year_plan.dart';
import 'package:bucket_app/screens/bucket_list_detail_screen.dart';
import 'package:bucket_app/screens/goal_detail_screen.dart';
import 'package:bucket_app/screens/goal_list_screen.dart';
import 'package:bucket_app/state/app_state.dart';

/// Wraps a screen widget with MaterialApp + Provider for testing.
Widget _wrapWithApp(Widget child, AppState state) {
  return ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(home: child),
  );
}

/// Creates AppState seeded with data via SharedPreferences.
Future<AppState> _seedState({
  List<Map<String, dynamic>>? bucketLists,
  List<YearPlan>? yearPlans,
}) async {
  final prefs = <String, Object>{'storage_version': 2};
  if (bucketLists != null) {
    prefs['bucket_lists'] =
        bucketLists.map((m) => json.encode(m)).toList();
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

Goal _habitGoal(String id, String title, {List<GoalLog>? logs}) => Goal(
      id: id,
      title: title,
      metricType: GoalMetricType.habit,
      target: GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: 3),
      logs: logs ?? [],
    );

Goal _totalGoal(String id, String title, {List<GoalLog>? logs}) => Goal(
      id: id,
      title: title,
      metricType: GoalMetricType.count,
      target: GoalTarget(
        mode: GoalTargetMode.total,
        targetTotalValue: 10.0,
        unit: GoalUnit.books,
      ),
      logs: logs ?? [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════
  // HomeScreen
  // ═══════════════════════════════════════════════════════════════

  group('HomeScreen', () {
    testWidgets('shows empty state when no bucket lists', (tester) async {
      final state = await _seedState();
      await tester.pumpWidget(_wrapWithApp(
        const Scaffold(body: Center(child: Text('test'))),
        state,
      ));
      // Use the full app to get the HomeScreen
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('아직 버킷리스트가 없어요'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows bucket list cards with progress', (tester) async {
      final state = await _seedState(bucketLists: [
        {
          'title': 'Travel',
          'items': [
            {'text': 'Paris', 'isDone': true},
            {'text': 'Tokyo', 'isDone': false},
          ],
        },
      ]);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('1 / 2 완료'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('add bucket list via FAB + dialog', (tester) async {
      final state = await _seedState();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('버킷리스트 추가'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'New List');
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.text('New List'), findsOneWidget);
      expect(find.text('아직 버킷리스트가 없어요'), findsNothing);
    });

    testWidgets('delete bucket list removes card', (tester) async {
      final state = await _seedState(bucketLists: [
        {'title': 'ToDelete', 'items': []},
      ]);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ToDelete'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('ToDelete'), findsNothing);
      expect(find.text('아직 버킷리스트가 없어요'), findsOneWidget);
    });

    testWidgets('edit dialog opens with existing title', (tester) async {
      final state = await _seedState(bucketLists: [
        {'title': 'Original', 'items': []},
      ]);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('버킷리스트 이름 수정'), findsOneWidget);
      // TextField should contain existing title
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, 'Original');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // BucketListDetailScreen
  // ═══════════════════════════════════════════════════════════════

  group('BucketListDetailScreen', () {
    testWidgets('shows empty state when no items', (tester) async {
      final state = await _seedState(bucketLists: [
        {'title': 'Empty List', 'items': []},
      ]);
      final bucketList = state.bucketLists[0];
      await tester.pumpWidget(_wrapWithApp(
        BucketListDetailScreen(listIndex: 0, bucketList: bucketList),
        state,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Empty List'), findsOneWidget);
      expect(find.text('세부 목표를 추가해보세요!'), findsOneWidget);
    });

    testWidgets('shows items with progress header', (tester) async {
      final state = await _seedState(bucketLists: [
        {
          'title': 'Goals',
          'items': [
            {'text': 'Item A', 'isDone': true},
            {'text': 'Item B', 'isDone': false},
          ],
        },
      ]);
      final bucketList = state.bucketLists[0];
      await tester.pumpWidget(_wrapWithApp(
        BucketListDetailScreen(listIndex: 0, bucketList: bucketList),
        state,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
      expect(find.text('1 / 2 완료'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('add item via FAB', (tester) async {
      final state = await _seedState(bucketLists: [
        {'title': 'Test', 'items': []},
      ]);
      final bucketList = state.bucketLists[0];
      await tester.pumpWidget(_wrapWithApp(
        BucketListDetailScreen(listIndex: 0, bucketList: bucketList),
        state,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('세부 목표 추가'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'New Item');
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.text('New Item'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GoalListScreen
  // ═══════════════════════════════════════════════════════════════

  group('GoalListScreen', () {
    testWidgets('shows empty state when no goals', (tester) async {
      // GoalListScreen has a tall CalendarDatePicker — use larger surface
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final yearPlan = YearPlan(id: 'yp1', year: 2026, goals: []);
      final state = await _seedState(yearPlans: [yearPlan]);
      await tester.pumpWidget(_wrapWithApp(
        GoalListScreen(yearPlan: yearPlan),
        state,
      ));
      await tester.pumpAndSettle();

      expect(find.text('목표를 추가해보세요!'), findsOneWidget);
    });

    testWidgets('shows goal cards with titles', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final yearPlan = YearPlan(id: 'yp1', year: 2026, goals: [
        _habitGoal('g1', 'Morning run'),
        _totalGoal('g2', 'Read books'),
      ]);
      final state = await _seedState(yearPlans: [yearPlan]);
      await tester.pumpWidget(_wrapWithApp(
        GoalListScreen(yearPlan: yearPlan),
        state,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Morning run'), findsOneWidget);
      expect(find.text('Read books'), findsOneWidget);
    });

    testWidgets('calendar is displayed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final yearPlan = YearPlan(id: 'yp1', year: 2026, goals: []);
      final state = await _seedState(yearPlans: [yearPlan]);
      await tester.pumpWidget(_wrapWithApp(
        GoalListScreen(yearPlan: yearPlan),
        state,
      ));
      await tester.pumpAndSettle();

      // CalendarDatePicker renders day numbers
      expect(find.byType(CalendarDatePicker), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GoalDetailScreen
  // ═══════════════════════════════════════════════════════════════

  group('GoalDetailScreen', () {
    testWidgets('shows goal not found state for invalid ids', (tester) async {
      final state = await _seedState();
      await tester.pumpWidget(_wrapWithApp(
        const GoalDetailScreen(yearPlanId: 'bad', goalId: 'bad'),
        state,
      ));
      await tester.pumpAndSettle();

      expect(find.text('목표를 찾을 수 없습니다'), findsOneWidget);
    });

    testWidgets('shows habit goal with streak and calendar', (tester) async {
      final logs = [
        GoalLog.habit(id: 'l1', date: DateTime.now()),
      ];
      final yearPlan = YearPlan(id: 'yp1', year: 2026, goals: [
        _habitGoal('g1', 'Meditate', logs: logs),
      ]);
      final state = await _seedState(yearPlans: [yearPlan]);
      await tester.pumpWidget(_wrapWithApp(
        const GoalDetailScreen(yearPlanId: 'yp1', goalId: 'g1'),
        state,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Meditate'), findsOneWidget);
      // Streak section visible
      expect(find.textContaining('연속'), findsWidgets);
    });

    testWidgets('shows total goal with progress stats', (tester) async {
      final logs = [
        GoalLog.increment(
            id: 'l1', date: DateTime(2026, 3, 5), amount: 3.0),
      ];
      final yearPlan = YearPlan(id: 'yp1', year: 2026, goals: [
        _totalGoal('g1', 'Read books', logs: logs),
      ]);
      final state = await _seedState(yearPlans: [yearPlan]);
      await tester.pumpWidget(_wrapWithApp(
        const GoalDetailScreen(yearPlanId: 'yp1', goalId: 'g1'),
        state,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Read books'), findsOneWidget);
      // Should show accumulated and remaining stats
      expect(find.textContaining('누적'), findsOneWidget);
      expect(find.textContaining('남은'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ReportScreen (via tab navigation)
  // ═══════════════════════════════════════════════════════════════

  group('ReportScreen', () {
    testWidgets('shows empty state when no data', (tester) async {
      final state = await _seedState();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      // Navigate to report tab
      await tester.tap(find.text('리포트'));
      await tester.pumpAndSettle();

      expect(find.text('아직 데이터가 없어요'), findsOneWidget);
    });

    testWidgets('shows stats when data exists', (tester) async {
      final state = await _seedState(
        bucketLists: [
          {
            'title': 'Test',
            'items': [
              {'text': 'A', 'isDone': true},
              {'text': 'B', 'isDone': false},
            ],
          },
        ],
      );
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('리포트'));
      await tester.pumpAndSettle();

      // Should show stat cards
      expect(find.text('총 목표'), findsOneWidget);
      expect(find.text('달성률'), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // OverviewCalendarScreen (via tab navigation)
  // ═══════════════════════════════════════════════════════════════

  group('OverviewCalendarScreen', () {
    testWidgets('shows stats and data management section', (tester) async {
      final state = await _seedState();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      // Navigate to overview tab
      await tester.tap(find.text('전체'));
      await tester.pumpAndSettle();

      expect(find.text('전체 보기'), findsOneWidget);
      expect(find.text('데이터 백업'), findsOneWidget);
      expect(find.text('데이터 복원'), findsOneWidget);
    });

    testWidgets('shows correct counts in stats', (tester) async {
      final state = await _seedState(
        bucketLists: [
          {'title': 'List1', 'items': []},
          {'title': 'List2', 'items': []},
        ],
        yearPlans: [
          YearPlan(id: 'yp1', year: 2026, goals: [
            _habitGoal('g1', 'Run'),
          ]),
        ],
      );
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('전체'));
      await tester.pumpAndSettle();

      // Should show bucket list count and goal count
      expect(find.text('2'), findsOneWidget); // bucket lists
      expect(find.text('1'), findsOneWidget); // goals
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Tab Navigation
  // ═══════════════════════════════════════════════════════════════

  group('Tab Navigation', () {
    testWidgets('all 4 tabs are accessible', (tester) async {
      final state = await _seedState();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const BucketApp(),
      ));
      await tester.pumpAndSettle();

      // Home tab (default)
      expect(find.text('버킷리스트'), findsOneWidget);

      // Goals tab
      await tester.tap(find.text('목표'));
      await tester.pumpAndSettle();
      expect(find.text('연도별 목표'), findsOneWidget);

      // Overview tab
      await tester.tap(find.text('전체'));
      await tester.pumpAndSettle();
      expect(find.text('전체 보기'), findsOneWidget);

      // Report tab
      await tester.tap(find.text('리포트'));
      await tester.pumpAndSettle();
      expect(find.text('리포트'), findsWidgets);
    });
  });
}
