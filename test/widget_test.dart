import 'package:flutter_test/flutter_test.dart';
import 'package:rust_book/main.dart';

void main() {
  testWidgets('RustBookApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RustBookApp());

    // Basic assertion that the app was built
    expect(find.byType(RustBookApp), findsOneWidget);
  });
}
