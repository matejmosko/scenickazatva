import 'package:flutter/material.dart';

class GameScoreCard extends StatelessWidget {
  final int correctCount;
  final int totalCount;
  final int score;
  final int totalPoints;

  const GameScoreCard({
    Key? key,
    required this.correctCount,
    required this.totalCount,
    required this.score,
    required this.totalPoints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final allCorrect = correctCount == totalCount && totalCount > 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              allCorrect
                  ? Icons.emoji_events
                  : (correctCount > totalCount / 2
                      ? Icons.thumb_up
                      : Icons.info_outline),
              size: 56,
              color: allCorrect
                  ? Colors.amber
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              "$correctCount / $totalCount správne",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (totalPoints > 0) ...[
              const SizedBox(height: 4),
              Text(
                "Celkové skóre: $score / $totalPoints bodov",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
