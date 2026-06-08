import 'package:flutter_test/flutter_test.dart';
import 'package:habo/main.dart';

void main() {
  testWidgets('Habo widget class is defined', (WidgetTester tester) async {
    expect(Habo.new, isA<Function>());
  });
}
