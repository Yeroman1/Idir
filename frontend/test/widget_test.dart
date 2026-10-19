import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/main.dart';

void main() {
  testWidgets('IdirApp smoke test', (WidgetTester tester) async {
    expect(IdirApp.new, isNotNull);
  });
}
