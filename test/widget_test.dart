import 'package:flutter_test/flutter_test.dart';
import 'package:robot_logo_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('starts on idle logo screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RobotLogoApp());
    await tester.pumpAndSettle();

    expect(find.text('触摸屏幕进入'), findsOneWidget);
    expect(find.text('请输入密码'), findsNothing);
    expect(find.text('主界面'), findsNothing);
  });

  testWidgets('shows change password entry after unlock', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RobotLogoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('触摸屏幕进入'));
    await tester.pumpAndSettle();

    for (final digit in ['2', '5', '8', '0']) {
      await tester.tap(find.text(digit));
      await tester.pumpAndSettle();
    }

    expect(find.text('主界面'), findsOneWidget);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('完整自适应'), findsOneWidget);
    expect(find.text('铺满裁剪'), findsOneWidget);
    expect(find.text('拉伸铺满'), findsOneWidget);
    expect(find.text('90°'), findsOneWidget);
  });
}
