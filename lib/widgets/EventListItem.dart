import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';
import 'package:scenickazatva_app/utils/TimeUtils.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

class EventListItem extends StatelessWidget {
  final dynamic event; // Should ideally be Event type
  final Festival festival;

  const EventListItem({Key? key, required this.event, required this.festival}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final festivalStart = TimeUtils.fromUtc(event.startTime);

    final startTime = DateFormat("HH:mm").format(festivalStart);
    final location = event.location ?? '';
    final now = DateTime.now();
    final playing = event.startTime.isBefore(now) && event.endTime.isAfter(now);

    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    final fp = Provider.of<FestivalProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = event.type == "offprogram"
        ? fp.offProgramColor
        : event.type == "partner"
            ? fp.partnerProgramColor
            : fp.mainProgramColor;

    final cardColor = isDark
        ? Color.alphaBlend(baseColor.withValues(alpha: 0.1), Theme.of(context).cardTheme.color!)
        : baseColor;

    return GestureDetector(
      onTap: () => context.go("/events/${event.id}"),
      child: Card(
        shape: RoundedRectangleBorder(
          side: playing ? BorderSide(color: isDark ? Colors.white54 : Colors.black, width: 2.0) : BorderSide.none,
          borderRadius: BorderRadius.circular(5.0),
        ),
        color: cardColor,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: 60,
                child: Column(
                  children: [
                    eventsProvider.getLocationIcon(location, color: eventsProvider.getLocationColor(location), size: 26),
                    Text(
                      location,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: eventsProvider.getLocationColor(location)),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      startTime,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title ?? '',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Consumer<UserProvider>(
                        builder: (context, userProvider, child) {
                          final isFav = userProvider.isFavorite(festival.id, event.id);
                          return IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : null,
                              size: 20,
                            ),
                            onPressed: () {
                              userProvider.toggleFavorite(festival.id, event);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  LimitedBox(
                    maxHeight: 70,
                    child: Text(
                      StringUtils.stripHtml(event.description ?? ""),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14.0),
                    ),
                  ),
                ],
              ),
            ),
            _buildImage(event.image, festival.logo),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl, String fallbackUrl) {
    return SizedBox(
      width: 120,
      height: 120,
      child: FirebaseImage(
        url: imageUrl,
        fallbackUrl: fallbackUrl,
        fit: BoxFit.cover,
        placeholder: Image.asset('assets/images/icon512.png', fit: BoxFit.cover),
      ),
    );
  }
}
