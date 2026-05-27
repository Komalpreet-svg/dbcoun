import 'package:flutter_test/flutter_test.dart';
import 'package:dbrcoun/main.dart';

void main() {
  testWidgets('Server Manager app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ServerApp());
    await tester.pump();

    // The app title should be present
    expect(find.text('Server Manager'), findsOneWidget);
    // The tabs should be present
    expect(find.text('DEV'), findsOneWidget);
    expect(find.text('QA'), findsOneWidget);
    expect(find.text('PROD'), findsOneWidget);
  });
}
