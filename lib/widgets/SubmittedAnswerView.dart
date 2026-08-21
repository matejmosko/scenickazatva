import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';

class SubmittedAnswerView extends StatelessWidget {
  final GameQuestion question;
  final Map<String, dynamic> answer;

  const SubmittedAnswerView({
    Key? key,
    required this.question,
    required this.answer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String text;
    switch (question.type) {
      case GameQuestionType.text:
      case GameQuestionType.textarea:
        text = answer['text']?.toString() ?? "";
        break;
      case GameQuestionType.abc:
        final indexes = (answer['indexes'] as List?)?.whereType<int>().toList() ?? [];
        indexes.sort();
        text = indexes.map((i) => i < question.options.length ? question.options[i] : "?").join(", ");
        break;
      case GameQuestionType.sort:
        final order = (answer['order'] as List?)?.whereType<String>().toList() ?? [];
        text = order.join(" → ");
        break;
      case GameQuestionType.match:
        final mapping = (answer['mapping'] as Map?) ?? {};
        text = question.pairs.map((p) => "${p.left} → ${mapping[p.left] ?? '?'}").join(", ");
        break;
    }

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tvoja odpoveď:",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
