import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/InfoPost.dart';
import 'package:scenickazatva_app/providers/InfoProvider.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/requests/api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as MD;
import 'package:go_router/go_router.dart';

class InfoDetailPage extends StatelessWidget {
  final infoId;

  InfoDetailPage({@required this.infoId});

  @override
  Widget build(BuildContext context) {
    final InfoProvider infoProvider = Provider.of<InfoProvider>(context);
    InfoPost info = InfoPost();
    List<InfoPost> information = infoProvider.info;
    if (information.where((element) => (element.id == infoId)).length > 0) {
      info = information.where((element) => (element.id == infoId)).toList()[0];
    }
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
          "",
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
                          API().launchURL(url),
                    ))
              ],
            ))
          ],
        ),
      ),
    );
  }
}
