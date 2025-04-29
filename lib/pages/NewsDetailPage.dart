import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/requests/api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:wordpress_client/wordpress_client.dart';
import 'package:scenickazatva_app/models/PostExtension.dart';

class NewsDetailPage extends StatelessWidget {
  final newsId;

  NewsDetailPage({@required this.newsId});

  @override
  Widget build(BuildContext context) {
    Post news = Post(
      id: 0,
      slug: "",
      status: getContentStatusFromValue(null),
      link: "",
      author: 0,
      commentStatus: getStatusFromValue(null),
      pingStatus: getStatusFromValue(null),
      sticky: false,
      format: getFormatFromValue(null),
      self: {},
    );

    var title = GoRouterState.of(context).uri.toString().contains("news") ? "Festivalové novinky" : "javisko.sk";

    Future<Post> getArticle() async {
      final NewsProvider newsProvider = Provider.of<NewsProvider>(context);
      List<Post> allNews = newsProvider.wpnews;
      List<Post> allArticles = newsProvider.wparticles;

      if (GoRouterState.of(context).uri.toString().contains("magazine") &&
          allArticles.map((element) => (element.id == newsId)).length > 0) {
        news = allArticles
            .where((element) => (element.id.toString() == newsId))
            .toList()[0];
        return news;
      } else if (GoRouterState.of(context).uri.toString().contains("news") &&
          allNews.map((element) => (element.id == newsId)).length > 0) {
        news = allNews
            .where((element) => (element.id.toString() == newsId))
            .toList()[0];
        return news;
      } else
        return Future.error("No data yet.");
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
            ),
            onPressed: () {
              GoRouterState.of(context).uri.toString().contains("magazine")
                  ? context.go("/magazine")
                  : context.go("/news");
            }),
        title: Text(
          title,
        ),
      ),
      body: SafeArea(
        child: FutureBuilder(
            future: getArticle(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.waiting &&
                  !snapshot.hasError) {
                return ListView(
                  children: [
                    CachedNetworkImage(
                      imageUrl: news.featuredImageSourceUrl(),
                      placeholder: (context, url) =>
                          Image.asset('assets/images/icon512.png'),
                      errorWidget: (context, url, error) =>
                          Image.asset('assets/images/icon512.png'),
                    ),
                    Card(
                      child: Column(
                        children: <Widget>[
                          Text("${news.title!.rendered!.replaceAll('&amp;', '&')}",
                              style: Theme.of(context).textTheme.displayLarge),
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: //Text("${news.content ?? ''}"),
                                Html(
                              data: news.content!.rendered,
                              onLinkTap: (url, map, element) =>
                                  API().launchURL(url),
                              style:{
                                "img": Style(
                                    width: Width(MediaQuery.of(context).size.width - 80), // not working as intended.
                              )},
                              extensions: [
                                ImageExtension(builder: (extensionContext) {
                                  final element = extensionContext.styledElement
                                      as ImageElement;
                                  return InteractiveViewer(
                                    boundaryMargin: const EdgeInsets.all(20.0),
                                    minScale: 1.0,
                                    maxScale: 2.0,
                                    child: CachedNetworkImage(
                                          imageUrl: element.src,
                                          //fit: BoxFit.fill,
                                          alignment: Alignment.center,
                                        ),
                                  );
                                }),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                );
              } else
                return Row(children: [
                  Text(
                    "...",
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                ]);
            }),
      ),
    );
  }
}
