import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:academia_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AcademiaApp());

    // Verify that our app starts with the home screen
    expect(find.text('Academia - Projet Supabase'), findsOneWidget);
  });
}
