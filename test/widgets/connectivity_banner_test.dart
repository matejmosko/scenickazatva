import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/requests/ConnectivityService.dart';
import 'package:scenickazatva_app/widgets/ConnectivityBanner.dart';

void main() {
  setUp(() {
    ConnectivityService.instance.debugSetOnline(true);
  });

  testWidgets('banner is hidden while online and shown while offline',
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

  testWidgets(
      'banner claims zero space while online and the status bar inset plus its height while offline',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: 24)),
          child: Scaffold(body: ConnectivityBanner()),
        ),
      ),
    );
    RenderBox box() => tester.renderObject<RenderBox>(find.byType(ConnectivityBanner));
    expect(box().size.height, 0);

    ConnectivityService.instance.debugSetOnline(false);
    await tester.pumpAndSettle();
    expect(box().size.height, 24 + 36);

    ConnectivityService.instance.debugSetOnline(true);
    await tester.pumpAndSettle();
    expect(box().size.height, 0);
  });
}
