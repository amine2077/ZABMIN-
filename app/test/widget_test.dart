import 'package:flutter_test/flutter_test.dart';
import 'package:zabmin/main.dart';

void main() {
  testWidgets('Dashboard loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ZabminApp());
    expect(find.text('Zabmin'), findsOneWidget);
  });
}
