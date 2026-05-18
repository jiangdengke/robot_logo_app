import 'package:flutter_test/flutter_test.dart';
import 'package:robot_logo_app/main.dart';

void main() {
  testWidgets('starts on idle logo screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RobotLogoApp());

    expect(find.text('触摸屏幕进入'), findsOneWidget);
    expect(find.text('请输入密码'), findsNothing);
    expect(find.text('主界面'), findsNothing);
  });
}
