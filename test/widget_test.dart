import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/main.dart';

void main() {
  testWidgets('home page shows learning overview and can start practice', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('今日练习'), findsOneWidget);
    expect(find.text('课程路线'), findsOneWidget);

    await tester.tap(find.text('开始练习'));
    await tester.pumpAndSettle();

    expect(find.textContaining('题目'), findsOneWidget);
  });
}
