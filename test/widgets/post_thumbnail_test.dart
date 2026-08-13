import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenickazatva_app/widgets/PostThumbnail.dart';

void main() {
  testWidgets('renders a fixed-size thumbnail', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PostThumbnail(imageUrl: '')),
      ),
    );

    expect(find.byType(PostThumbnail), findsOneWidget);
    expect(
      tester.getSize(find.byType(PostThumbnail)),
      const Size(120, 120),
    );
  });
}
