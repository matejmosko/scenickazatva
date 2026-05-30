import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:scenickazatva_app/models/PostExtension.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';

class NewsView extends StatefulWidget {
  @override
  _NewsViewState createState() => _NewsViewState();
}

class _NewsViewState extends State<NewsView> with AutomaticKeepAliveClientMixin {
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
            ),
            onChanged: (value) {
              setState(() {}); // To update suffixIcon visibility
            },
            onSubmitted: (value) {
              newsProvider.setNewsSearchQuery(value.isEmpty ? null : value);
            },
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

                            return Card(
                              child: GestureDetector(
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Expanded(
                                          child: ListTile(
                                            title: Text(
                                              item.title!.rendered!.replaceAll('&amp;', '&') ?? "",
                                              style: Theme.of(context).textTheme.titleMedium,
                                            ),
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
                                    Analytics().sendEvent(item.title!.rendered);
                                    Analytics().sendEvent("javisko article opened");
                                    context.go("/news/" + item.id.toString());
                                  }),
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
    );
  }
}
