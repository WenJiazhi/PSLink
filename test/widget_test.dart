// PSLink Widget Test

import 'package:flutter_test/flutter_test.dart';

import 'package:pslink/main.dart';

void main() {
  testWidgets('PSLink app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PSLinkApp());

    // Verify that PSLink title is present
    expect(find.text('PSLink'), findsOneWidget);
  });
}
