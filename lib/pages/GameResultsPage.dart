import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:scenickazatva_app/models/GameParticipant.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';

/// Admin view: lists all participants ranked by score so the organizer can
/// declare the quiz winner on the draw date.
class GameResultsPage extends StatefulWidget {
  const GameResultsPage({Key? key}) : super(key: key);

  @override
  State<GameResultsPage> createState() => _GameResultsPageState();
}

class _GameResultsPageState extends State<GameResultsPage> {
  bool _authorized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_authorized) {
      final canEdit = Provider.of<UserProvider>(context).canEdit;
      if (!canEdit) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/game');
          }
        });
      }
      _authorized = true;
    }
  }

  List<GameParticipant> _sortedParticipants(GameProvider provider) {
    final list = [...provider.participants];
    list.sort((a, b) {
      if (a.score != b.score) return b.score.compareTo(a.score);
      if (a.correctCount != b.correctCount) return b.correctCount.compareTo(a.correctCount);
      final t1 = a.lastAnsweredAt ?? DateTime(9999);
      final t2 = b.lastAnsweredAt ?? DateTime(9999);
      return t1.compareTo(t2);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/game'),
        ),
        title: const Text("Výsledky a víťaz"),
      ),
      body: provider.participants.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Zatiaľ sa nezúčastnil žiadny hráč.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            )
          : ListView.builder(
              itemCount: provider.participants.length,
              itemBuilder: (context, index) {
                final participant = _sortedParticipants(provider)[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text((index + 1).toString()),
                    ),
                    title: Text(
                      participant.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (participant.email.isNotEmpty)
                          Text(participant.email, style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          "Skóre: ${participant.score}  •  Správne: ${participant.correctCount}/${participant.answeredCount}",
                        ),
                        if (participant.lastAnsweredAt != null)
                          Text(
                            "Posledná odpoveď: ${DateFormat('d.M.yyyy HH:mm').format(participant.lastAnsweredAt!.toLocal())}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (participant.winner)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Text(
                              "VÍŤAZ",
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            participant.winner ? Icons.emoji_events : Icons.emoji_events_outlined,
                            color: participant.winner ? Colors.amber : Colors.grey,
                          ),
                          tooltip: participant.winner
                              ? "Odobrať víťazstvo"
                              : "Vyhlásiť víťaza",
                          onPressed: () {
                            provider.setWinner(
                              participant.uid,
                              winner: !participant.winner,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
