import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

void main() {
  testWidgets('shows the placeholder when url is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: FirebaseImage(url: '', placeholder: const Text('fallback')),
          ),
        ),
      ),
    );

    expect(find.text('fallback'), findsOneWidget);
  });

  testWidgets('shows the placeholder when url and fallback are empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: FirebaseImage(
              url: '',
              fallbackUrl: '',
              placeholder: const Icon(Icons.festival),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.festival), findsOneWidget);
  });
}
