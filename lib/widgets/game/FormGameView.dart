import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/providers/QuizDraftProvider.dart';
import 'package:scenickazatva_app/widgets/QuestionHeader.dart';
import 'package:scenickazatva_app/widgets/game/QuestionInput.dart';

class FormGameView extends StatelessWidget {
  final List<GameQuestion> questions;
  final Widget header;
  final bool submitting;
  final Function() onSubmit;

  const FormGameView({
    Key? key,
    required this.questions,
    required this.header,
    required this.submitting,
    required this.onSubmit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final draft = Provider.of<QuizDraftProvider>(context);
    final allAnswered = questions.every((q) => draft.hasAnswer(q.id));

    return ListView(
      children: [
        header,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            "Formulár",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (var i = 0; i < questions.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuestionHeader(question: questions[i], index: i, showPoints: false),
                  const SizedBox(height: 12),
                  QuestionInput(question: questions[i]),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: (submitting || !allAnswered) ? null : onSubmit,
            icon: submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text("Uložiť odpovede"),
          ),
        ),
        if (!allAnswered)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Vyplňte všetky otázky pred odovzdaním.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}
