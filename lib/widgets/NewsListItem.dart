import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wordpress_client/wordpress_client.dart' hide Widget, Theme;
import 'package:scenickazatva_app/models/PostExtension.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';
import 'package:scenickazatva_app/widgets/PostThumbnail.dart';

/// Shared list-item tile for both [NewsView] and [MagazineView].
class NewsListItem extends StatelessWidget {
  final Post item;
  final bool isSaved;
  final bool isRead;
  final String routePrefix;
  final String? label;
  final VoidCallback onToggleBookmark;
  final VoidCallback? onTap;

  const NewsListItem({
    super.key,
    required this.item,
    required this.isSaved,
    this.isRead = false,
    required this.routePrefix,
    this.label,
    required this.onToggleBookmark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: GestureDetector(
        onTap: onTap ??
            () {
              Analytics().logEvent(AnalyticsEvents.articleOpened, parameters: {
                AnalyticsEvents.paramItemId: item.id.toString(),
                AnalyticsEvents.paramTitle:
                    item.title?.rendered ?? '',
              });
              context.go("$routePrefix/${item.id}");
            },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ListTile(
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isRead)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 6.0, right: 8.0),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (label != null && label!.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 4.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  label!.toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                ),
                              ),
                            ),
                          Text(
                            item.title?.rendered
                                    ?.replaceAll('&amp;', '&') ??
                                "",
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isSaved
                            ? Icons.bookmark
                            : Icons.bookmark_outline,
                        color: isSaved
                            ? const Color(0xffCCA965)
                            : null,
                      ),
                      onPressed: onToggleBookmark,
                    ),
                  ],
                ),
                isThreeLine: true,
                subtitle: _buildSubtitle(context),
              ),
            ),
            PostThumbnail(
              imageUrl: item.featuredImageSourceUrl(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final stripped =
        StringUtils.stripHtml(item.excerpt?.rendered ?? "");
    return Text(
      stripped.length > 100
          ? "${stripped.substring(0, 100)}..."
          : stripped,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontSize: 14.0),
    );
  }
}
