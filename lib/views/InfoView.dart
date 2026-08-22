import 'package:flutter/material.dart';
import 'package:scenickazatva_app/providers/InfoProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';
import 'package:scenickazatva_app/widgets/DynamicIcon.dart';
import 'package:scenickazatva_app/widgets/GameCard.dart';
import 'package:scenickazatva_app/widgets/FestivalInfoCard.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

class InfoView extends StatefulWidget {
  @override
  State<InfoView> createState() => _InfoViewState();
}

class _InfoViewState extends State<InfoView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final InfoProvider infoProvider = Provider.of<InfoProvider>(context);
    final fest = Provider.of<FestivalProvider>(context).festival;

    return Stack(
      children: [
        Positioned.fill(
          child: FirebaseImage(
            url: fest.background,
            fit: BoxFit.cover,
          ),
        ),
        Center(
          child: AnimatedOpacity(
            opacity: infoProvider.loading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: const Text(
              "Načítavam...",
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: (infoProvider.info.isNotEmpty || !infoProvider.loading) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Column(
            children: [
              const GameCard(),
              const FestivalInfoCard(),
              Expanded(
                child: Card(
                  child: ListView.builder(
                    itemCount: infoProvider.info.length,
                    itemBuilder: (BuildContext context, int index) {
                      final item = infoProvider.info[index];
                      return ListTile(
                          title: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          isThreeLine: true,
                          leading: DynamicIcon(codePoint: item.icon, size: 24),
                          subtitle: Text(
                            StringUtils.stripHtml(item.description),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14.0),
                            overflow: TextOverflow.fade,
                            maxLines: 2,
                          ),
                          onTap: () {
                            Analytics().logEvent(AnalyticsEvents.infoOpened, parameters: {
                              AnalyticsEvents.paramItemId: item.id,
                            });
                            context.go("/info/" + item.id);
                          });
                    },
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
