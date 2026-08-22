import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameSubmission.dart';
import 'package:scenickazatva_app/widgets/GameScoreCard.dart';
import 'package:scenickazatva_app/widgets/QuestionSummaryCard.dart';

class QuizSummary extends StatelessWidget {
  final List<GameQuestion> questions;
  final Map<String, GameSubmission> submissions;
  final int score;
  final int totalPoints;
  final Widget? header;
  final VoidCallback? onRestart;

  const QuizSummary({
    Key? key,
    required this.questions,
    required this.submissions,
    required this.score,
    required this.totalPoints,
    this.header,
    this.onRestart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final correctCount = submissions.values.where((s) => s.correct).length;
    final totalCount = questions.length;

    return ListView(
      children: [
        if (header != null) header!,
        GameScoreCard(
          correctCount: correctCount,
          totalCount: totalCount,
          score: score,
          totalPoints: totalPoints,
        ),
        if (onRestart != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh),
              label: const Text("Hrať znova"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            "Prehľad odpovedí",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (var i = 0; i < questions.length; i++)
          QuestionSummaryCard(
            question: questions[i],
            submission: submissions[questions[i].id],
            index: i,
          ),
        const SizedBox(height: 100),
      ],
    );
  }
}
