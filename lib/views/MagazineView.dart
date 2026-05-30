import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/models/PostExtension.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';

class MagazineView extends StatefulWidget {
  @override
  _MagazineViewState createState() => _MagazineViewState();
}

class _MagazineViewState extends State<MagazineView> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final NewsProvider newsProvider = Provider.of<NewsProvider>(context);

    return Column(
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
                              newsProvider.setMagazineSearchQuery(null);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                  onSubmitted: (value) {
                    newsProvider.setMagazineSearchQuery(value.isEmpty ? null : value);
                  },
                ),
              ),
              if (newsProvider.magazineCategories.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
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
              if (newsProvider.articlesLoading && newsProvider.wparticles.isEmpty)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (!newsProvider.articlesLoading && newsProvider.wparticles.isEmpty)
                const Center(
                  child: Text("Nenašli sa žiadne články"),
                ),
              Column(
                children: [
                  if (newsProvider.unreadMagazineCount > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${newsProvider.unreadMagazineCount} neprečítaných",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed: () => newsProvider.markAllMagazineAsRead(),
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
                      onEndOfPage: () => newsProvider.fetchWpMagazine(fetchMore: true),
                      isLoading: newsProvider.articlesLoading,
                      scrollOffset: 50,
                      child: RefreshIndicator(
                        onRefresh: () => newsProvider.fetchWpMagazine(refresh: true),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: newsProvider.wparticles.length,
                          itemBuilder: (BuildContext context, int index) {
                            final item = newsProvider.wparticles[index];
                            return Card(
                              child: GestureDetector(
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Expanded(
                                          child: ListTile(
                                            title: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (!newsProvider.isRead(item.id))
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 6.0, right: 8.0),
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
                                                  child: Text(
                                                    item.title?.rendered?.replaceAll('&amp;', '&') ?? "",
                                                    style: Theme.of(context).textTheme.titleMedium,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            isThreeLine: true,
                                            subtitle: Builder(
                                              builder: (context) {
                                                final stripped = StringUtils.stripHtml(item.excerpt?.rendered ?? "");
                                                return Text(
                                                  stripped.length > 100
                                                      ? "${stripped.substring(0, 100)}..."
                                                      : stripped,
                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 120.0,
                                          height: 120.0,
                                          child: CachedNetworkImage(
                                            imageUrl: item.featuredImageSourceUrl(),
                                            fit: BoxFit.cover,
                                            height: double.infinity,
                                            width: double.infinity,
                                            placeholder: (context, url) => Image.asset('assets/images/icon512.png'),
                                            errorWidget: (context, url, error) => Image.asset('assets/images/icon512.png'),
                                          ),
                                        ),
                                      ]),
                                  onTap: () {
                                    newsProvider.markAsRead(item.id);
                                    Analytics().sendEvent(item.title!.rendered);
                                    Analytics().sendEvent("festník article opened");
                                    context.go("/magazine/" + item.id.toString());
                                  }),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (newsProvider.articlesLoading && newsProvider.wparticles.isNotEmpty)
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
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    final newsProvider = Provider.of<NewsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: newsProvider.selectedMagazineCategoryId,
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
          ...newsProvider.magazineCategories.map((category) {
            return DropdownMenuItem<int?>(
              value: category.id,
              child: Text(category.name ?? ""),
            );
          }).toList(),
        ],
        onChanged: (int? value) {
          newsProvider.setMagazineCategory(value);
        },
      ),
    );
  }
}
