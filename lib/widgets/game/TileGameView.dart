import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';

class TileGameView extends StatelessWidget {
  final List<GameQuestion> questions;
  final Widget header;
  final String gameId;

  const TileGameView({
    Key? key,
    required this.questions,
    required this.header,
    required this.gameId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        header,
        if (questions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              "Otázky",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Otázky pridáme čoskoro.",
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ...questions.map((q) => _buildQuestionTile(context, q)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildQuestionTile(BuildContext context, GameQuestion q) {
    final provider = Provider.of<GameProvider>(context);
    final answered = provider.isAnswered(q.id);
    final submission = provider.submissionFor(q.id);
    final isTextarea = q.type == GameQuestionType.textarea;

    final IconData statusIcon;
    final Color statusColor;
    if (!answered || submission == null) {
      statusIcon = isTextarea ? Icons.notes : Icons.radio_button_unchecked;
      statusColor = Colors.grey;
    } else if (submission.correct) {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    } else {
      statusIcon = isTextarea ? Icons.check_circle : Icons.cancel;
      statusColor = isTextarea ? Colors.green : Colors.orange;
    }

    return Card(
      child: ListTile(
        leading: Icon(_typeIcon(q.type), color: Theme.of(context).colorScheme.primary),
        title: Text(q.title),
        subtitle: q.description.isNotEmpty
            ? Text(
                q.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isTextarea)
              Text("${q.points} b", style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            Icon(statusIcon, color: statusColor),
          ],
        ),
        onTap: () {
          Analytics().logEvent(AnalyticsEvents.gameQuestionOpened, parameters: {
            AnalyticsEvents.paramQuestionId: q.id,
          });
          context.go("/game/$gameId/${q.id}");
        },
      ),
    );
  }

  static IconData _typeIcon(GameQuestionType type) {
    switch (type) {
      case GameQuestionType.text: return Icons.text_fields;
      case GameQuestionType.abc: return Icons.radio_button_checked;
      case GameQuestionType.sort: return Icons.swap_vert;
      case GameQuestionType.match: return Icons.link;
      case GameQuestionType.textarea: return Icons.notes;
    }
  }
}
