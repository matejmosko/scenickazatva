import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:scenickazatva_app/models/GameParticipant.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';

/// Displays participants who correctly answered all game questions.
class GameWinnersPage extends StatelessWidget {
  final String gameId;
  const GameWinnersPage({super.key, required this.gameId});

  List<GameParticipant> _getWinners(GameProvider provider) {
    final totalQuestions = provider.questions.length;
    if (totalQuestions == 0) return [];

    final winners = provider.participants.where((p) => p.correctCount == totalQuestions).toList();

    // Sort by lastAnsweredAt (oldest first)
    winners.sort((a, b) {
      final t1 = a.lastAnsweredAt ?? DateTime(9999);
      final t2 = b.lastAnsweredAt ?? DateTime(9999);
      return t1.compareTo(t2);
    });

    return winners;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final winners = _getWinners(provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Úspešní riešitelia"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/game/$gameId'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: winners.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Zatiaľ nikto nezodpovedal všetky otázky správne. Buď prvý!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: winners.length,
              itemBuilder: (context, index) {
                final winner = winners[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        (index + 1).toString(),
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                    ),
                    title: Text(
                      winner.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: winner.lastAnsweredAt != null
                        ? Text(
                            "Dokončené: ${DateFormat('d.M.yyyy HH:mm').format(winner.lastAnsweredAt!.toLocal())}",
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : null,
                    trailing: const Icon(Icons.emoji_events, color: Colors.amber),
                  ),
                );
              },
            ),
    );
  }
}
