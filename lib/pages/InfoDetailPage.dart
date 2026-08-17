import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/InfoPost.dart';
import 'package:scenickazatva_app/providers/InfoProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as MD;
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/widgets/DeepLinkButton.dart';

class InfoDetailPage extends StatelessWidget {
  final infoId;
  InfoDetailPage({required this.infoId});

  @override
  Widget build(BuildContext context) {
    // Get the info post data
    final infoProvider = Provider.of<InfoProvider>(context);
    final info = infoProvider.info.firstWhere(
          (element) => element.id == infoId,
      orElse: () => InfoPost(),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
            ),
            onPressed: () {
              context.go("/info");
            }),
        title: const Text(
          "Informácie",
        ),
        actions: <Widget>[
          const DeepLinkButton(),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              Analytics().logEvent(AnalyticsEvents.menuSettings);
              context.go('/settings');
            },
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            CachedNetworkImage(
                imageUrl: info.image,
                placeholder: (context, url) => SizedBox.shrink(),
                errorWidget: (context, url, error) => SizedBox.shrink()),
            Card(
                child: Column(
              children: <Widget>[
                ListTile(
                  title: Text("${info.title}"),
                ),
                Padding(
                    padding: EdgeInsets.all(12),
                    child: Html(
                      data: MD.markdownToHtml(info.description),
                      onLinkTap: (url, map, element) {
                        if (url != null) {
                          SystemServices().launchURL(url);
                        }
                      },
                      style: {
                        "a": Style(
                          color: Colors.blue,
                          textDecoration: TextDecoration.underline,
                        ),
                      },
                      extensions: [
                        MatcherExtension(
                          matcher: (extensionContext) =>
                              extensionContext.elementName == "a" &&
                              extensionContext.attributes['class'] == 'button',
                          builder: (extensionContext) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  final url =
                                      extensionContext.attributes['href'];
                                  if (url != null) {
                                    SystemServices().launchURL(url);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child:
                                    Text(extensionContext.element?.text ?? ""),
                              ),
                            );
                          },
                        ),
                      ],
                    ))
              ],
            ))
          ],
        ),
      ),
      floatingActionButton: (context.watch<UserProvider>().canEdit)
          ? FloatingActionButton(
              onPressed: () => context.go("/info/${info.id}/edit"),
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }
}
