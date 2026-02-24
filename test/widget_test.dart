import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bucket_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('main tabs render and can switch to report', (tester) async {
    await tester.pumpWidget(const BucketApp());
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('목표'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('리포트'), findsOneWidget);

    await tester.tap(find.text('리포트'));
    await tester.pumpAndSettle();

    expect(find.text('리포트'), findsWidgets);
    expect(find.textContaining('요약'), findsOneWidget);
  });
}
