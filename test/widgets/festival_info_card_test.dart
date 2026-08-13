import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/widgets/FestivalInfoCard.dart';

void main() {
  FestivalProvider providerWith(String id, String title, {String logo = ''}) {
    final provider = FestivalProvider();
    provider.updateFromSettings(AppSettings(
      defaultfestival: id,
      festivals: {
        id: Festival(id: id, title: title, logo: logo),
      },
    ));
    return provider;
  }

  Widget wrap(FestivalProvider provider) {
    return ChangeNotifierProvider<FestivalProvider>.value(
      value: provider,
      child: const MaterialApp(home: Scaffold(body: FestivalInfoCard())),
    );
  }

  testWidgets('hides when the festival title is empty', (tester) async {
    final provider = providerWith('zatva', '');
    await tester.pumpWidget(wrap(provider));

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('shows title, subtitle and date range without touching Firebase',
      (tester) async {
    final provider = providerWith(
      'zatva',
      'Scénická žatva',
      logo: '',
    );
    await tester.pumpWidget(wrap(provider));

    expect(find.text('Scénická žatva'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });
}
