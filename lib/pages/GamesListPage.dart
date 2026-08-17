import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/widgets/DeepLinkButton.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

/// Lists all games for the current festival.
/// Admins see all games; non-admins see only published/ended ones.
class GamesListPage extends StatelessWidget {
  const GamesListPage({Key? key}) : super(key: key);

  static String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Koncept';
      case 'published':
        return 'Publikovaná';
      case 'ended':
        return 'Ukončená';
      default:
        return status;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange;
      case 'published':
        return Colors.green;
      case 'ended':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final canEdit = Provider.of<UserProvider>(context).canEdit;
    final visible = provider.visibleGames;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/info'),
        ),
        title: const Text("Festivalové hry"),
        actions: const [
          DeepLinkButton(),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          "Zatiaľ žiadne hry.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                      if (canEdit) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () async {
                            final id = await provider.createGame();
                            if (id != null && context.mounted) {
                              Analytics().logEvent(AnalyticsEvents.gameCreateOpened);
                              context.go('/game/$id');
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text("Vytvoriť hru"),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final game = visible[index];
                    final statusColor = _statusColor(game.status);
                    return Card(
                      child: ListTile(
                        leading: game.imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: FirebaseImage(
                                    url: game.imageUrl,
                                    fit: BoxFit.cover,
                                    errorPlaceholder: Icon(
                                      Icons.emoji_events,
                                      size: 40,
                                      color: game.status == 'ended' ? Colors.grey : Colors.amber,
                                    ),
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.emoji_events,
                                size: 40,
                                color: game.status == 'ended' ? Colors.grey : Colors.amber,
                              ),
                        title: Text(
                          game.title.isNotEmpty ? game.title : "Bez názvu",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _statusLabel(game.status),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: statusColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${game.questions.length} otázok",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Analytics().logEvent(AnalyticsEvents.gameOpened);
                          provider.selectGame(game.id);
                          context.go('/game/${game.id}');
                        },
                      ),
                    );
                  },
            ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () async {
                final id = await provider.createGame();
                if (id != null && context.mounted) {
                  Analytics().logEvent(AnalyticsEvents.gameCreateOpened);
                  context.go('/game/$id');
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
