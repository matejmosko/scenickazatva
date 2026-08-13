import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Offline-friendly queue of articles the user saved for later. Entries are
/// stored locally (title/excerpt/image) so the list is browsable without a
/// connection.
class ReadLaterPage extends StatelessWidget {
  const ReadLaterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final newsProvider = Provider.of<NewsProvider>(context);
    final posts = newsProvider.readLaterPosts;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prečítam neskôr"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              Analytics().logEvent(AnalyticsEvents.menuSettings);
              context.go('/settings');
            },
          )
        ],
      ),
      body: posts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "Zatiaľ nemáte žiadne články uložené.\nStlačením ikony záložky si ich môžete odložiť na neskôr.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final String link = post['link']?.toString() ?? '';
                return Dismissible(
                  key: ValueKey(link),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => newsProvider.removeReadLater(link),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    child: ListTile(
                      leading: SizedBox(
                        width: 60,
                        height: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: post['image']?.toString().isNotEmpty == true
                              ? CachedNetworkImage(
                                  imageUrl: post['image'].toString(),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.article),
                                )
                              : const Icon(Icons.article_outlined),
                        ),
                      ),
                      title: Text(
                        post['title']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        post['excerpt']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14.0),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => newsProvider.removeReadLater(link),
                      ),
                      onTap: () {
                        final route = post['route']?.toString() ?? '';
                        if (route.isNotEmpty) {
                          context.go(route);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
