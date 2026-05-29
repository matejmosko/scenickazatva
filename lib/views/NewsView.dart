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
            opacity: newsProvider.newsLoading ? 1.0 : 0.0,
            duration: Duration(milliseconds: 500),
            // The green box must be a child of the AnimatedOpacity widget.
            child: Text(
              "Načítavam...",
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: newsProvider.wpnews.length > 0 ? 1.0 : 0.0,
          duration: Duration(milliseconds: 500),
          child: Container(
              child: Column(
            children: <Widget>[
              Flexible(
                child: LazyLoadScrollView(
                  onEndOfPage: () => newsProvider.fetchWpNews(fetchMore: true),
                  isLoading: newsProvider.newsLoading,
                  scrollOffset: 50,
                  child: RefreshIndicator(
                      child: ListView.builder(
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
                                          //item['_embedded'][0]['wp:featuredimage']['source_url'] ?? "",
                                          imageUrl: item.featuredImageSourceUrl(),
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
                                  Analytics().sendEvent(item.title!.rendered);
                                  Analytics().sendEvent("javisko article opened");
                                  context.go("/news/" + item.id.toString());
/*                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NewsDetailPage(
                                      newsId: item.id,
                                    ),
                                  ),
                                );*/
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
                            newsProvider.fetchWpNews(refresh: true);
                          });
                        });
                      }),
                ),
              ),
              Container(
                  child: (newsProvider.newsLoading)
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
}
