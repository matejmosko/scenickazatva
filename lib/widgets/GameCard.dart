import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';

/// Shows the festival game status (or an admin shortcut to create one).
class GameCard extends StatelessWidget {
  const GameCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);

    if (!gameProvider.hasGame) {
      final canEdit = Provider.of<UserProvider>(context).canEdit;
      if (!canEdit) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.all(8.0),
        child: ListTile(
          leading: Icon(Icons.add_circle_outline,
              size: 40, color: Theme.of(context).colorScheme.primary),
          title: const Text("Pridať festivalovú hru"),
          subtitle: const Text("Vytvor kvíz pre návštevníkov festivalu."),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Analytics().logEvent(AnalyticsEvents.gameCreateOpened);
            context.go('/game/edit');
          },
        ),
      );
    }

    final game = gameProvider.game!;
    final total = gameProvider.questions.length;
    final answered = gameProvider.answeredCount;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: const Icon(Icons.emoji_events, size: 40, color: Colors.amber),
        title: Text(
          game.title.isEmpty ? "Festivalová hra" : game.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          "Zodpovedané: $answered / $total   •   Skóre: ${gameProvider.score}",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Analytics().logEvent(AnalyticsEvents.gameOpened);
          context.go("/game");
        },
      ),
    );
  }
}
