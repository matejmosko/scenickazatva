import 'package:flutter/material.dart';
import 'package:scenickazatva_app/providers/InfoProvider.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';
import 'package:scenickazatva_app/requests/ImagePrecacheService.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/widgets/DynamicIcon.dart';

class InfoView extends StatefulWidget {
  @override
  State<InfoView> createState() => _InfoViewState();
}

class _InfoViewState extends State<InfoView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final InfoProvider infoProvider = Provider.of<InfoProvider>(context);

    return Stack(
      children: [
        Center(
          child: AnimatedOpacity(
            opacity: infoProvider.loading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: const Text(
              "Načítavam...",
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: (infoProvider.info.isNotEmpty || !infoProvider.loading) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Column(
            children: [
              _buildGameCard(context),
              _buildFestivalInfo(context),
              Expanded(
                child: Card(
                  child: ListView.builder(
                    itemCount: infoProvider.info.length,
                    itemBuilder: (BuildContext context, int index) {
                      final item = infoProvider.info[index];
                      return ListTile(
                          title: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          isThreeLine: true,
                          leading: DynamicIcon(codePoint: item.icon, size: 24),
                          subtitle: Text(
                            StringUtils.stripHtml(item.description),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14.0),
                            overflow: TextOverflow.fade,
                            maxLines: 2,
                          ),
                          onTap: () {
                            Analytics().sendEvent(item.title);
                            context.go("/info/" + item.id);
                          });
                    },
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildGameCard(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);

    if (!gameProvider.hasGame) {
      final canEdit = Provider.of<UserProvider>(context).canEdit;
      if (!canEdit) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.all(8.0),
        child: ListTile(
          leading: Icon(Icons.add_circle_outline,
              size: 40, color: Theme.of(context).colorScheme.primary),
          title: const Text("Pridať festivalovú hru"),
          subtitle: const Text("Vytvor kvíz pre návštevníkov festivalu."),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Analytics().sendEvent("game create opened");
            context.go('/game/edit');
          },
        ),
      );
    }

    final game = gameProvider.game!;
    final total = gameProvider.questions.length;
    final answered = gameProvider.answeredCount;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: const Icon(Icons.emoji_events, size: 40, color: Colors.amber),
        title: Text(
          game.title.isEmpty ? "Festivalová hra" : game.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          "Zodpovedané: $answered / $total   •   Skóre: ${gameProvider.score}",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Analytics().sendEvent("game opened");
          context.go("/game");
        },
      ),
    );
  }

  Widget _buildFestivalInfo(BuildContext context) {
    final festivalProvider = Provider.of<FestivalProvider>(context);
    final fest = festivalProvider.festival;

    if (fest.title.isEmpty) return const SizedBox.shrink();

    final dateRange = fest.startDate != null && fest.endDate != null
        ? "${DateFormat("d.M.").format(fest.startDate!)} – ${DateFormat("d.M. yyyy").format(fest.endDate!)}"
        : "";

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (fest.logo.isNotEmpty)
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 16),
                child: FutureBuilder<bool>(
                  future: ImagePrecacheService().doesImageExist(fest.logo),
                  builder: (context, snapshot) {
                    final exists = snapshot.data ?? (ImagePrecacheService().checkCache(fest.logo) ?? false);
                    if (!exists) {
                      return const Icon(Icons.festival, size: 40);
                    }
                    return Image(
                      image: FirebaseImageProvider(FirebaseUrl(fest.logo)),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.festival, size: 40),
                    );
                  },
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fest.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (fest.subtitle.isNotEmpty)
                    Text(
                      fest.subtitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  if (dateRange.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        dateRange,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
