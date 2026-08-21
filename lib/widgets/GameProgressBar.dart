import 'package:flutter/material.dart';

/// Progress bar with "Zodpovedané X/Y" and "Skóre X/Y" labels.
class GameProgressBar extends StatelessWidget {
  final int answered;
  final int total;
  final int score;
  final int totalPoints;
  const GameProgressBar({
    Key? key,
    required this.answered,
    required this.total,
    required this.score,
    required this.totalPoints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : answered / total;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, minHeight: 8),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Zodpovedané: $answered / $total"),
            Text("Skóre: $score / $totalPoints"),
          ],
        ),
      ],
    );
  }
}

/// Compact slide indicator: "Otázka X / Y" with progress bar.
class SlideIndicator extends StatelessWidget {
  final int current;
  final int total;
  const SlideIndicator({Key? key, required this.current, required this.total})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            "Otázka ${current + 1} / $total",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? (current + 1) / total : 0,
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
