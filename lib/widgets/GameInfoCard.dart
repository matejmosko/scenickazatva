import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scenickazatva_app/models/GameConfig.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

/// Shows game image, description, and end date. Used in header card and start screen.
class GameInfoCard extends StatelessWidget {
  final GameConfig game;
  const GameInfoCard({Key? key, required this.game}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (game.imageUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: FirebaseImage(
                url: game.imageUrl,
                fit: BoxFit.cover,
                errorPlaceholder: const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (game.description.isNotEmpty) ...[
          Text(game.description),
          const SizedBox(height: 12),
        ],
        if (game.endsAt != null) ...[
          Row(
            children: [
              Icon(Icons.emoji_events,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "Vyžrebovanie víťaza: ${DateFormat('d.M.yyyy').format(game.endsAt!)}",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
