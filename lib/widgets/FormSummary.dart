import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameSubmission.dart';
import 'package:scenickazatva_app/widgets/QuestionSummaryCard.dart';

class FormSummary extends StatelessWidget {
  final List<GameQuestion> questions;
  final Map<String, GameSubmission> submissions;
  final Widget? header;
  final VoidCallback? onRestart;

  const FormSummary({
    Key? key,
    required this.questions,
    required this.submissions,
    this.header,
    this.onRestart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (header != null) header!,
        Card(
          margin: const EdgeInsets.all(12),
          color: Colors.green,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Formulár úspešne odoslaný",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        "Ďakujeme za tvoje odpovede.",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onRestart != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh),
              label: const Text("Vyplniť znova"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            "Tvoje odpovede",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (var i = 0; i < questions.length; i++)
          QuestionSummaryCard(
            question: questions[i],
            submission: submissions[questions[i].id],
            index: i,
            showCorrectness: false,
          ),
        const SizedBox(height: 100),
      ],
    );
  }
}
