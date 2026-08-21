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

  const QuizSummary({
    Key? key,
    required this.questions,
    required this.submissions,
    required this.score,
    required this.totalPoints,
    this.header,
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
