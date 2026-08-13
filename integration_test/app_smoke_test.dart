import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scenickazatva_app/main.dart' as app;

/// Smoke test: boots the real app entry point and waits until the main tab
/// bar is built. Requires a device/emulator with network access to Firebase
/// (run with `flutter test integration_test -d <device>`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and renders the navigation bar', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    var found = false;
    for (var i = 0; i < 20 && !found; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      found = find.byType(NavigationBar).evaluate().isNotEmpty;
    }
    expect(found, isTrue, reason: 'NavigationBar was not rendered on boot');
  });
}
