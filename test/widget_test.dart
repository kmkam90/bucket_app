import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bucket_app/main.dart';
import 'package:bucket_app/state/app_state.dart';

Widget _createApp() {
  return ChangeNotifierProvider(
    create: (_) => AppState()..init(),
    child: const BucketApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders with bottom navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(_createApp());
    await tester.pumpAndSettle();

    // 하단 네비게이션 바 존재 확인
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('목표'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('리포트'), findsOneWidget);
  });

  testWidgets('Home tab shows empty state', (WidgetTester tester) async {
    await tester.pumpWidget(_createApp());
    await tester.pumpAndSettle();

    // 빈 상태 메시지 표시
    expect(find.text('아직 버킷리스트가 없어요'), findsOneWidget);

    // FAB 존재
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Home tab adds a bucket list', (WidgetTester tester) async {
    await tester.pumpWidget(_createApp());
    await tester.pumpAndSettle();

    // + 버튼 탭
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // 다이얼로그에서 이름 입력
    await tester.enterText(find.byType(TextField), '2026년 버킷리스트');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // 버킷리스트 추가 확인
    expect(find.text('2026년 버킷리스트'), findsOneWidget);
    expect(find.text('아직 버킷리스트가 없어요'), findsNothing);
  });

  testWidgets('Home tab delete button exists after adding', (WidgetTester tester) async {
    await tester.pumpWidget(_createApp());
    await tester.pumpAndSettle();

    // 버킷리스트 추가
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '테스트 리스트');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // 삭제 아이콘 존재 (AppBar의 선택삭제 + 카드의 삭제)
    expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);
  });

  testWidgets('Navigate to goals tab', (WidgetTester tester) async {
    await tester.pumpWidget(_createApp());
    await tester.pumpAndSettle();

    // 목표 탭으로 이동
    await tester.tap(find.text('목표'));
    await tester.pumpAndSettle();

    // 연도별 목표 화면 확인
    expect(find.text('연도별 목표'), findsOneWidget);
    expect(find.text('아직 등록된 연도가 없어요'), findsOneWidget);
  });

  testWidgets('Goals tab adds a year', (WidgetTester tester) async {
    await tester.pumpWidget(_createApp());
    await tester.pumpAndSettle();

    // 목표 탭으로 이동
    await tester.tap(find.text('목표'));
    await tester.pumpAndSettle();

    // 연도 추가
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2026');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.text('2026'), findsOneWidget);
    expect(find.text('목표 0개'), findsOneWidget);
  });

  testWidgets('Goals tab prevents duplicate year', (WidgetTester tester) async {
    await tester.pumpWidget(_createApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('목표'));
    await tester.pumpAndSettle();

    // 첫 번째 연도 추가
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2026');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    // 같은 연도 다시 추가 시도
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2026');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    // 중복 경고 SnackBar
    expect(find.text('2026년은 이미 존재합니다.'), findsOneWidget);
  });

  testWidgets('Year delete button shows confirmation', (WidgetTester tester) async {
    await tester.pumpWidget(_createApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('목표'));
    await tester.pumpAndSettle();

    // 연도 추가
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2026');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    // 삭제 버튼 탭
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    // 확인 다이얼로그 표시
    expect(find.text('2026년 삭제'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });
}
