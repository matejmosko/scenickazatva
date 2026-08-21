import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/GameQuestion.dart';
import 'package:scenickazatva_app/pages/GamePage.dart';

/// Standard question header with type icon, index, title, description, and points.
/// [statusIcon] / [statusColor] override the default type icon (e.g. for correct/wrong indicators).
class QuestionHeader extends StatelessWidget {
  final GameQuestion question;
  final int index;
  final IconData? statusIcon;
  final Color? statusColor;
  const QuestionHeader({
    Key? key,
    required this.question,
    required this.index,
    this.statusIcon,
    this.statusColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isTextarea = question.type == GameQuestionType.textarea;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              statusIcon ?? GamePage.typeIcon(question.type),
              size: 20,
              color: statusColor ?? Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "${index + 1}. ${question.title}",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (!isTextarea)
              Text("${question.points} b",
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (question.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(question.description,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
