import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/models/PostExtension.dart';

class MagazineView extends StatefulWidget {

  @override
  _MagazineViewState createState() => _MagazineViewState();
}

class _MagazineViewState extends State<MagazineView>
    with TickerProviderStateMixin {

  static String stripHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
  }

  Widget build(BuildContext context) {
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
          opacity: newsProvider.wparticles.length > 0 ? 1.0 : 0.0,
          duration: Duration(milliseconds: 500),
          child: Container(
              child: Column(
            children: <Widget>[
              Flexible(
                child: LazyLoadScrollView(
                  onEndOfPage: () =>
                      newsProvider.fetchWpMagazine(),
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
                                          title:
                                              Text(item.title!.rendered!.replaceAll('&amp;', '&') ?? ""),
                                          isThreeLine: true,
                                         /* subtitle: Html(
                                            data: item.excerpt!.rendered!
                                                    .substring(0, 105) ??
                                                "",
                                            shrinkWrap: true,
                                          ),*/
                                          subtitle: Text(stripHtml(item.excerpt!.rendered ?? "").length > 100 ? stripHtml(item.excerpt!.rendered ?? "").substring(1,100)+"..." : stripHtml(item.excerpt!.rendered ?? "")),
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
}
