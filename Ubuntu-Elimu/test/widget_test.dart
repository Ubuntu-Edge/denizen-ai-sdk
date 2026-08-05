import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_elimu/app.dart';

void main() {
  testWidgets('Smoke test for Ubuntu Elimu App', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UbuntuElimuApp());

    // Verify that home screen components render successfully
    expect(find.text('Good morning'), findsOneWidget);
  });
}
