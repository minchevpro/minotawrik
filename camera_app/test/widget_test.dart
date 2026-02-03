import 'package:flutter_test/flutter_test.dart';
import 'package:camera_app/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(camera: null));

    // Check if it shows "No camera available" when camera is null
    expect(find.text('No camera available'), findsOneWidget);
  });
}
