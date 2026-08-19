import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/requests/ConnectivityService.dart';
import 'package:scenickazatva_app/widgets/ConnectivityBanner.dart';

void main() {
  setUp(() {
    ConnectivityService.instance.hideBanner();
    ConnectivityService.instance.debugSetOnline(true);
  });

  testWidgets('banner shows when going offline and hides when back online',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ConnectivityBanner())),
    );
    expect(find.textContaining('Ste offline'), findsNothing);

    ConnectivityService.instance.debugSetOnline(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ste offline'), findsOneWidget);

    ConnectivityService.instance.debugSetOnline(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ste offline'), findsNothing);
  });

  testWidgets('banner shows for manual failure and auto-hides',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ConnectivityBanner())),
    );
    expect(find.textContaining('Nepodarilo'), findsNothing);

    ConnectivityService.instance
        .showTemporaryBanner('Nepodarilo sa uložiť — skúste znova');
    await tester.pumpAndSettle();
    expect(find.textContaining('Nepodarilo'), findsOneWidget);

    ConnectivityService.instance.hideBanner();
    await tester.pumpAndSettle();
    expect(find.textContaining('Nepodarilo'), findsNothing);
  });

  testWidgets('banner claims zero space when hidden and non-zero when shown',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ConnectivityBanner())),
    );
    RenderBox box() =>
        tester.renderObject<RenderBox>(find.byType(ConnectivityBanner));
    expect(box().size.height, 0);

    ConnectivityService.instance.debugSetOnline(false);
    await tester.pumpAndSettle();
    expect(box().size.height, greaterThan(0));

    ConnectivityService.instance.debugSetOnline(true);
    await tester.pumpAndSettle();
    expect(box().size.height, 0);
  });
}
