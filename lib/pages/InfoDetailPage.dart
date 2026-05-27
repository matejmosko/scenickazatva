import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/InfoPost.dart';
import 'package:scenickazatva_app/providers/InfoProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as MD;
import 'package:go_router/go_router.dart';

class InfoDetailPage extends StatelessWidget {
  final infoId;
  InfoDetailPage({required this.infoId});

  @override
  Widget build(BuildContext context) {
    // 1. Get the current festival (and watch for changes)
    final festival = context.watch<FestivalProvider>().festival;

    // 2. Get the info post data
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
        title: Text(
          festival.title,
        ),
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
                      onLinkTap: (url, map, element) =>
                          SystemServices().launchURL(url!),
                    ))
              ],
            ))
          ],
        ),
      ),
    );
  }
}
