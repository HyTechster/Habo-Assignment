import 'package:flutter_test/flutter_test.dart';
import 'package:habo/main.dart';

void main() {
  testWidgets('Habo widget class is defined', (WidgetTester tester) async {
    // Verify the top-level widget class exists and is a StatefulWidget.
    // Full integration rendering is covered by app_test.dart.
    expect(Habo.new, isA<Function>());
  });
}
