import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:academia_app/config/supabase_config.dart';
import 'package:academia_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Provide an in-memory SharedPreferences backend for tests so that
    // Supabase's SharedPreferences-based storage works without plugins.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Minimal Supabase initialisation so that providers depending on
    // Supabase.instance can be constructed during widget tests.
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const AcademiaApp());

    // Pump a few frames to let the widget tree build.
    // We avoid pumpAndSettle because the app has persistent timers/animations
    // (e.g. hero carousel, weather polling) that never fully settle.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Basic smoke check: the app builds and shows a Material widget tree
    // without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
