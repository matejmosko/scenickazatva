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

class _MagazineViewState extends State<MagazineView>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final NewsProvider newsProvider = Provider.of<NewsProvider>(context);


    return Stack(
      children: [
        Center(
          child: AnimatedOpacity(
            // If the widget is visible, animate to 0.0 (invisible).
            // If the widget is hidden, animate to 1.0 (fully visible).
            opacity: newsProvider.articlesLoading ? 1.0 : 0.0,
            duration: Duration(milliseconds: 500),
            // The green box must be a child of the AnimatedOpacity widget.
            child: Text(
              "Načítavam...",
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 500),
          child: Container(
              child: Column(
            children: <Widget>[
              if (newsProvider.magazineCategories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                  child: _buildCategoryDropdown(context),
                ),
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
              Flexible(
                child: LazyLoadScrollView(
                  onEndOfPage: () =>
                      newsProvider.fetchWpMagazine(fetchMore: true),
                  isLoading: newsProvider.articlesLoading,
                  scrollOffset: 50,
                  child: RefreshIndicator(
                      child: ListView.builder(
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
                                          imageUrl:
                                              item.featuredImageSourceUrl(),
                                          fit: BoxFit.cover,
                                          height: double.infinity,
                                          width: double.infinity,
                                          placeholder: (context, url) =>
                                              Image.asset(
                                                  'assets/images/icon512.png'),
                                          errorWidget: (context, url, error) =>
                                              Image.asset(
                                                  'assets/images/icon512.png'),
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
                      onRefresh: () {
                        return Future.delayed(Duration(seconds: 0), () {
                          /// adding elements in list after [1 seconds] delay
                          /// to mimic network call
                          ///
                          /// Remember: [setState] is necessary so that
                          /// build method will run again otherwise
                          /// list will not show all elements
                          setState(() {
                            newsProvider.fetchWpMagazine(
                                refresh: true);
                          });
                        });
                      }),
                ),
              ),
              Container(
                  child: (newsProvider.articlesLoading)
                      ? Padding(
                          padding: EdgeInsets.all(10),
                      child: new CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent)))
                      : new Row())
            ],
          )),
        )
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
        hint: const Text("Všetky kategórie"),
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
