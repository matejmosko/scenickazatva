import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';
import 'package:provider/provider.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:scenickazatva_app/widgets/NewsListItem.dart';

class NewsView extends StatefulWidget {
  @override
  _NewsViewState createState() => _NewsViewState();
}

class _NewsViewState extends State<NewsView> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  Widget _buildCategoryDropdown(BuildContext context) {
    final newsProvider = Provider.of<NewsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: newsProvider.selectedNewsCategoryId,
        isExpanded: true,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black,
          fontSize: 14,
          fontFamily: 'Space Grotesk',
        ),
        hint: const Text("Kategórie"),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text("Všetky kategórie"),
          ),
          ...newsProvider.newsCategories.map((category) {
            return DropdownMenuItem<int?>(
              value: category.id,
              child: Text(category.name ?? ""),
            );
          }).toList(),
        ],
        onChanged: (int? value) {
          newsProvider.setNewsCategory(value);
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final NewsProvider newsProvider = Provider.of<NewsProvider>(context);
    final fest = Provider.of<FestivalProvider>(context).festival;

    return Stack(
      children: [
        Positioned.fill(
          child: FirebaseImage(
            url: fest.background,
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Hľadať...',
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  newsProvider.setNewsSearchQuery(null);
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                        filled: true,
                        fillColor: Theme.of(context).canvasColor.withValues(alpha: 0.8),
                      ),
                      onChanged: (value) {
                        setState(() {}); // To update suffixIcon visibility
                      },
                      onSubmitted: (value) {
                        newsProvider.setNewsSearchQuery(value.isEmpty ? null : value);
                      },
                    ),
                  ),
                  if (newsProvider.newsCategories.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).canvasColor.withValues(alpha: 0.8),
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _buildCategoryDropdown(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  if (newsProvider.newsLoading && newsProvider.wpnews.isEmpty)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else if (!newsProvider.newsLoading && newsProvider.wpnews.isEmpty)
                    const Center(
                      child: Text("Nenašli sa žiadne články"),
                    ),
                  Column(
                    children: [
                      if (newsProvider.unreadNewsCount > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${newsProvider.unreadNewsCount} neprečítaných",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              TextButton(
                                onPressed: () => newsProvider.markAllNewsAsRead(),
                                child: Text(
                                  "Označiť všetky ako prečítané",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: LazyLoadScrollView(
                          onEndOfPage: () => newsProvider.fetchWpNews(fetchMore: true),
                          isLoading: newsProvider.newsLoading,
                          scrollOffset: 50,
                          child: RefreshIndicator(
                            onRefresh: () => newsProvider.fetchWpNews(refresh: true),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: newsProvider.wpnews.length,
                              itemBuilder: (BuildContext context, int index) {
                                final item = newsProvider.wpnews[index];

                                return NewsListItem(
                                  item: item,
                                  isSaved: newsProvider.isReadLater(item.link),
                                  isRead: newsProvider.isRead(item.id),
                                  routePrefix: "/news",
                                  onToggleBookmark: () =>
                                      newsProvider.toggleReadLater(item,
                                          route: "/news/${item.id}"),
                                  onTap: () {
                                    newsProvider.markAsRead(item.id);
                                    context.go("/news/${item.id}");
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      if (newsProvider.newsLoading && newsProvider.wpnews.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
