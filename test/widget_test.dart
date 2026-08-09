import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/main.dart';

void main() {
  testWidgets('app launches and renders home without crashing', (tester) async {
    await tester.pumpWidget(const MyApp());

    // 允许初始化（加载题库、首页）完成；用多次 pump 避免在测试环境中
    // 因后台 Timer / 平台视图导致 pumpAndSettle 挂起。
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // 至少应构建出 MaterialApp（加载页或首页），证明启动链路无异常
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
