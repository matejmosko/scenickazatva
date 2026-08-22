import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameParticipant.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameType.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';

/// Displays all participants ranked by score.
/// By default shows only players who answered all quiz questions correctly.
/// Admins can toggle winner status; non-admins see the leaderboard.
class GameResultsPage extends StatefulWidget {
  final String gameId;
  const GameResultsPage({Key? key, required this.gameId}) : super(key: key);

  @override
  State<GameResultsPage> createState() => _GameResultsPageState();
}

class _GameResultsPageState extends State<GameResultsPage> {
  bool _showAll = false;

  List<GameParticipant> _sortedParticipants(
      List<GameParticipant> participants, GameType gameType) {
    final list = [...participants];
    if (gameType == GameType.form) {
      // Form: rank by number of submissions (most active first), then time.
      list.sort((a, b) {
        if (a.answeredCount != b.answeredCount) {
          return b.answeredCount.compareTo(a.answeredCount);
        }
        final t1 = a.lastAnsweredAt ?? DateTime(9999);
        final t2 = b.lastAnsweredAt ?? DateTime(9999);
        return t1.compareTo(t2);
      });
    } else {
      // Quiz/Game: rank by score, then correctCount, then time.
      list.sort((a, b) {
        if (a.score != b.score) return b.score.compareTo(a.score);
        if (a.correctCount != b.correctCount) {
          return b.correctCount.compareTo(a.correctCount);
        }
        final t1 = a.lastAnsweredAt ?? DateTime(9999);
        final t2 = b.lastAnsweredAt ?? DateTime(9999);
        return t1.compareTo(t2);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final canEdit = Provider.of<UserProvider>(context).canEdit;
    final gameType = provider.game?.type ?? GameType.game;
    final isForm = gameType == GameType.form;

    final scoredQuestionCount = provider.questions
        .where((q) => q.type != GameQuestionType.textarea)
        .length;

    final totalQuestionCount = provider.questions.length;

    var sorted = _sortedParticipants(provider.participants, gameType);

    final allSolved = scoredQuestionCount > 0 &&
        sorted.every((p) => p.correctCount >= scoredQuestionCount);

    // Form type: "show all" toggle doesn't apply (no correctness concept).
    // Quiz/Game: filter to only perfect scores unless "show all".
    if (!isForm && !_showAll && scoredQuestionCount > 0 && !allSolved) {
      sorted = sorted.where((p) => p.correctCount >= scoredQuestionCount).toList();
    }

    final subtitleLabel = isForm
        ? "Počet odpovedí"
        : "Správne";

    final countDenom = isForm ? totalQuestionCount : scoredQuestionCount;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/game/${widget.gameId}'),
        ),
        title: Text(canEdit ? "Výsledky a víťaz" : (isForm ? "Účastníci" : "Úspešní riešitelia")),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => context.go('/settings'),
          ),
        ],
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
          : Column(
              children: [
                if (provider.participants.isNotEmpty && !isForm)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _showAll
                                ? "Všetci hráči (${provider.participants.length})"
                                : "Úspešní riešitelia (${sorted.length})",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        if (!allSolved)
                          TextButton(
                            onPressed: () => setState(() => _showAll = !_showAll),
                            child: Text(_showAll ? "Len úspešní" : "Všetci hráči"),
                          ),
                      ],
                    ),
                  ),
                if (isForm)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      "Všetci účastníci (${provider.participants.length})",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                Expanded(
                  child: sorted.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              isForm
                                  ? "Zatiaľ sa nikto nezúčastnil."
                                  : "Zatiaľ nikto nezodpovedal všetky otázky správne. Buď prvý!",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final participant = sorted[index];
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
                                    if (isForm)
                                      Text(
                                        "$subtitleLabel: ${participant.answeredCount}/$countDenom",
                                      )
                                    else
                                      Text(
                                        "Skóre: ${participant.score}  •  $subtitleLabel: ${participant.correctCount}/$countDenom",
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
                                    if (canEdit)
                                      IconButton(
                                        icon: Icon(
                                          participant.winner
                                              ? Icons.emoji_events
                                              : Icons.emoji_events_outlined,
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
                                      )
                                    else if (participant.winner)
                                      const Icon(Icons.emoji_events, color: Colors.amber),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
