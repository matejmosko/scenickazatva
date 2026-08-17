import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';

/// Shows a "Festivalové hry" card linking to the games list.
/// Non-admins only see the card when there are published/ended games.
class GameCard extends StatelessWidget {
  const GameCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final canEdit = Provider.of<UserProvider>(context).canEdit;

    // Non-admins only see the card when there are visible games
    if (!canEdit && !gameProvider.hasGames) return const SizedBox.shrink();
    if (!canEdit && gameProvider.visibleGames.isEmpty) return const SizedBox.shrink();

    final gameCount = gameProvider.visibleGames.length;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: Icon(
          Icons.emoji_events,
          size: 40,
          color: gameProvider.hasGames ? Colors.amber : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          "Festivalové hry",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          canEdit
              ? "$gameCount ${_gameCountLabel(gameCount)}"
              : "$gameCount aktívnych",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Analytics().logEvent(AnalyticsEvents.gameOpened);
          context.go("/games");
        },
      ),
    );
  }

  static String _gameCountLabel(int count) {
    if (count == 1) return "hra";
    if (count >= 2 && count <= 4) return "hry";
    return "hier";
  }
}
