import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/models/GameSubmission.dart';
import 'package:scenickazatva_app/widgets/QuestionHeader.dart';
import 'package:scenickazatva_app/widgets/SubmittedAnswerView.dart';

class QuestionSummaryCard extends StatelessWidget {
  final GameQuestion question;
  final GameSubmission? submission;
  final int index;
  final bool showCorrectness;

  const QuestionSummaryCard({
    Key? key,
    required this.question,
    required this.submission,
    required this.index,
    this.showCorrectness = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isTextarea = question.type == GameQuestionType.textarea;
    final correct = submission?.correct ?? false;
    final statusColor = (isTextarea || !showCorrectness)
        ? Theme.of(context).colorScheme.primary
        : (correct ? Colors.green : Colors.orange);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QuestionHeader(
              question: question,
              index: index,
              statusIcon: (isTextarea || !showCorrectness)
                  ? Icons.check_circle
                  : (correct ? Icons.check_circle : Icons.cancel),
              statusColor: statusColor,
              showPoints: showCorrectness,
            ),
            const SizedBox(height: 16),
            if (submission != null)
              _buildStatusRow(context, isTextarea, correct),
            if (submission != null) ...[
              const SizedBox(height: 12),
              SubmittedAnswerView(question: question, answer: submission!.answer),
            ],
            if (showCorrectness && !correct && !isTextarea) ...[
              const SizedBox(height: 12),
              _buildCorrectAnswer(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, bool isTextarea, bool correct) {
    String label;
    if (isTextarea || !showCorrectness) {
      label = "Odpoveď bola uložená";
    } else {
      label = correct ? "Správna odpoveď!" : "Nesprávna odpoveď.";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isTextarea || !showCorrectness)
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : (correct ? Colors.green.shade50 : Colors.orange.shade50),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: (isTextarea || !showCorrectness)
                  ? Theme.of(context).colorScheme.primary
                  : (correct ? Colors.green[800] : Colors.orange[800]),
            ),
      ),
    );
  }

  Widget _buildCorrectAnswer(BuildContext context) {
    String correctText;
    switch (question.type) {
      case GameQuestionType.text:
        correctText = [question.answer, ...question.acceptableAnswers]
            .where((a) => a.isNotEmpty)
            .join(" / ");
        break;
      case GameQuestionType.abc:
        correctText = question.correctIndexes.map((i) => question.options[i]).join(", ");
        break;
      case GameQuestionType.sort:
        correctText = question.sortOrder.join(" → ");
        break;
      case GameQuestionType.match:
        correctText = question.pairs.map((p) => "${p.left} → ${p.right}").join(", ");
        break;
      default:
        correctText = "";
    }

    if (correctText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: Colors.green[700]),
              const SizedBox(width: 4),
              Text(
                "Správna odpoveď:",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green[700]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            correctText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green[800],
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
