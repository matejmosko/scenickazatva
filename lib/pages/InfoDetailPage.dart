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
    InfoPost info = infoProvider.info.where((element) => (element.id == infoId)).toList()[0];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
          ),
            onPressed: () {
              context.go("/info");
            }
        ),
        title: Text(
          "Scénická žatva 100",
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            Hero(
              child: info.image != null
                  ? CachedNetworkImage(
                      imageUrl: info.image,
                      placeholder: (context, url) =>
                          SizedBox.shrink(),
                      errorWidget: (context, url, error) =>
                          SizedBox.shrink())
                  : SizedBox(),
              tag: info.id,
            ),
            Card(
                child: Column(
              children: <Widget>[
                ListTile(
//                  leading: Text("$startTime$location$endTime"),
                  title: Text("${info.title ?? ''}"),
                ),
                info.description != null
                    ? Padding(
                        padding: EdgeInsets.all(12),
                        child: Html(
                          data: MD.markdownToHtml(info.description),
                          onLinkTap: (url, renderContext, map, element) => API().launchURL(url),
                        ))
                    : SizedBox.shrink()
              ],
            ))
          ],
        ),
      ),
    );
  }
}
