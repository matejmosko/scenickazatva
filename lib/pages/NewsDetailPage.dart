import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/models/PostExtension.dart';
import 'package:wordpress_client/wordpress_client.dart' as wpclient;

class NewsDetailPage extends StatefulWidget {
  final dynamic newsId;

  NewsDetailPage({required this.newsId});

  @override
  _NewsDetailPageState createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  late Future<wpclient.Post> _articleFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _articleFuture = _loadArticle();
  }

  Future<wpclient.Post> _loadArticle() async {
    final NewsProvider newsProvider =
        Provider.of<NewsProvider>(context, listen: false);
    List<wpclient.Post> allNews = newsProvider.wpnews;
    List<wpclient.Post> allArticles = newsProvider.wparticles;
    final String currentUri = GoRouterState.of(context).uri.toString();

    wpclient.Post? found;

    if (currentUri.contains("magazine")) {
      final matches = allArticles
          .where((element) => element.id.toString() == widget.newsId.toString())
          .toList();
      if (matches.isNotEmpty) {
        found = matches[0];
      }
    } else if (currentUri.contains("news")) {
      final matches = allNews
          .where((element) => element.id.toString() == widget.newsId.toString())
          .toList();
      if (matches.isNotEmpty) {
        found = matches[0];
      }
    }

    if (found != null) {
      // Schedule markAsRead to avoid calling notifyListeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          newsProvider.markAsRead(found!.id);
        }
      });
      return found;
    } else {
      throw "No data yet.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final newsProvider = Provider.of<NewsProvider>(context);
    var title = GoRouterState.of(context).uri.toString().contains("news")
        ? "Festivalové novinky"
        : "javisko.sk";

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
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              Analytics().sendEvent("menu: settings");
              context.go('/settings');
            },
          )
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<wpclient.Post>(
            future: _articleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.waiting &&
                  !snapshot.hasError &&
                  snapshot.hasData) {
                final news = snapshot.data!;
                return ListView(
                  children: [
                    Container(
                      constraints: BoxConstraints(
                          minHeight: 200,
                          minWidth: double.infinity,
                          maxHeight: 500),
                      child: Semantics(
                        label: "Hlavný obrázok článku",
                        child: CachedNetworkImage(
                          imageUrl: news.featuredImageSourceUrl(),
                          placeholder: (context, url) =>
                              Image.asset('assets/images/icon512.png'),
                          errorWidget: (context, url, error) =>
                              Image.asset('assets/images/icon512.png'),
                        ),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (newsProvider.getPostLabel(news.link).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        newsProvider.getPostLabel(news.link).toUpperCase(),
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  "${news.title?.rendered?.replaceAll('&amp;', '&') ?? ''}",
                                  style: Theme.of(context).textTheme.displayLarge,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Html(
                              data: news.content?.rendered ?? '',
                              onLinkTap: (url, map, element) {
                                if (url != null) {
                                  SystemServices().launchURL(url);
                                }
                              },
                              style: {
                                "body": Style(
                                  fontSize: FontSize(Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.fontSize ??
                                      14.0),
                                ),
                                "a": Style(
                                  color: Colors.blue,
                                  textDecoration: TextDecoration.underline,
                                ),
                                "img": Style(
                                  width: Width(
                                      MediaQuery.of(context).size.width - 80),
                                ),
                              },
                              extensions: [
                                MatcherExtension(
                                  matcher: (extensionContext) =>
                                      extensionContext.elementName == "a" &&
                                      extensionContext.attributes['class'] ==
                                          'button',
                                  builder: (extensionContext) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          final url = extensionContext
                                              .attributes['href'];
                                          if (url != null) {
                                            SystemServices().launchURL(url);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                            extensionContext.element?.text ??
                                                ""),
                                      ),
                                    );
                                  },
                                ),
                                ImageExtension(builder: (extensionContext) {
                                  final element = extensionContext.styledElement
                                      as ImageElement;
                                  return Semantics(
                                    label: element.alt ?? "Obrázok k článku",
                                    child: InteractiveViewer(
                                      boundaryMargin: const EdgeInsets.all(20.0),
                                      minScale: 1.0,
                                      maxScale: 2.0,
                                      child: CachedNetworkImage(
                                        imageUrl: element.src,
                                        alignment: Alignment.center,
                                      ),
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
              } else if (snapshot.hasError) {
                return Center(child: Text("Článok sa nepodarilo načítať"));
              } else {
                return Center(
                  child: Text(
                    "...",
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                );
              }
            }),
      ),
    );
  }
}
