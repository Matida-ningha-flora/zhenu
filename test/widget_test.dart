import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhendu_app/main.dart';

void main() {
  testWidgets('Smoke test - App starts and builds splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ZhenduApp());

    // Verify that the title and region descriptions are shown on Splash.
    expect(find.text('Zhẽnù'), findsOneWidget);
    expect(find.text('LANGUE DES SIGNES CAMEROUNAISE'), findsOneWidget);
  });
}
