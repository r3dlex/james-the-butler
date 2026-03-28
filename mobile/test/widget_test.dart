import 'package:flutter_test/flutter_test.dart';
import 'package:james_the_butler/main.dart';

void main() {
  testWidgets('App renders title text', (WidgetTester tester) async {
    await tester.pumpWidget(const JamesTheButlerApp());

    expect(find.text('James the Butler'), findsOneWidget);
  });
}
