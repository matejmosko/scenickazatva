import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:intl/intl.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as MD;
import 'package:go_router/go_router.dart';
import 'package:flutter/scheduler.dart';
import 'package:scenickazatva_app/utils/TimeUtils.dart';
import 'package:scenickazatva_app/requests/ImagePrecacheService.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;

  EventDetailPage({required this.eventId});

  @override
  _EventDetailPageState createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    Analytics().logEvent(AnalyticsEvents.eventOpened, parameters: {
      AnalyticsEvents.paramItemId: widget.eventId,
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Listen to EventsProvider for updates and loading state
    final eventsProvider = context.watch<EventsProvider>();
    
    // 2. If loading, show a loading indicator instead of prematurely redirecting
    if (eventsProvider.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final events = eventsProvider.events;
    Event? event;
    final found = events.where((element) => (element.id == widget.eventId));
    if (found.isNotEmpty) {
      event = found.first;
    }

    // 3. Robust redirect logic with guards
    if (event == null || event.id == "") {
      if (!_isRedirecting) {
        _isRedirecting = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/events');
          }
        });
      }
      return const Scaffold();
    }

    final startDate = event.startTime != null
        ? DateFormat("E, d.M.", "sk_SK")
            .format(TimeUtils.fromUtc(event.startTime!))
        : '';
    final startTime = event.startTime != null
        ? DateFormat("HH:mm")
            .format(TimeUtils.fromUtc(event.startTime!))
        : '';
    final endTime = event.endTime != null
        ? "\n${DateFormat("HH:mm")
            .format(TimeUtils.fromUtc(event.endTime!))}"
        : '';

    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final festival = festivalProvider.festival;

    final now = DateTime.now();
    final playing = event.startTime != null && event.endTime != null &&
        event.startTime!.isBefore(now) && event.endTime!.isAfter(now);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
            ),
            onPressed: () {
              context.go("/events");
            }),
        title: Text(
          event.title,
        ),
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              final isFav = userProvider.isFavorite(festival.id, event!.id);
              return IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : null,
                ),
                onPressed: () {
                  userProvider.toggleFavorite(festival.id, event!);
                },
              );
            },
          ),
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
            SizedBox(
              height: 300,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: event.type == "OFF" ? festivalProvider.offProgramColor : festivalProvider.mainProgramColor,
                      ),
                      child: FutureBuilder<bool>(
                  future: event.image.isNotEmpty ? ImagePrecacheService().doesImageExist(event.image) : Future.value(false),
                  builder: (context, snapshot) {
                    final bool exists = snapshot.data ?? (ImagePrecacheService().checkCache(event!.image) ?? false);
                    final String effectiveUrl = exists ? event!.image : festival.logo;

                    if (effectiveUrl.isEmpty) {
                      return Image.asset('assets/images/icon512.png', fit: BoxFit.cover);
                    }

                    return Image(
                      image: FirebaseImageProvider(FirebaseUrl(effectiveUrl)),
                      fit: BoxFit.cover,
                      height: 300,
                      width: double.infinity,
                      errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                        if (effectiveUrl == festival.logo || festival.logo.isEmpty) {
                          return Image.asset('assets/images/icon512.png', fit: BoxFit.cover);
                        }
                        return Image(
                          image: FirebaseImageProvider(FirebaseUrl(festival.logo)),
                          fit: BoxFit.cover,
                          height: 300,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Image.asset('assets/images/icon512.png', fit: BoxFit.cover),
                        );
                      },
                    );
                  },
                ),
                    ),
                  ),
                  if (playing)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                          ],
                        ),
                        child: const Text(
                          "Práve prebieha",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Card(
              child: Column(children: <Widget>[
                Container(
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Theme.of(context).dividerColor))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center, // Perfect vertical centering
                        children: <Widget>[
                          // 1. Time & Date Section (1/4 - Left Aligned)
                          Flexible(
                            flex: 1,
                            fit: FlexFit.tight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  startTime,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  "- ${endTime.trim()}",
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  startDate.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // 2. Title Section (2/4 - Left Aligned Prominent)
                          Flexible(
                            flex: 4,
                            fit: FlexFit.tight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  event.title,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                    fontSize: 18,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                ),
                                if (event.artist.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      event.artist,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 3. Location Section (1/4 - Center Aligned)
                          Flexible(
                            flex: 1,
                            fit: FlexFit.tight,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                eventsProvider.getLocationIcon(event.location, color: eventsProvider.getLocationColor(event.location), size: 26),
                                const SizedBox(height: 4),
                                Text(
                                  eventsProvider.getLocationName(event.location),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: eventsProvider.getLocationColor(event.location),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                event.description != ""
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Html(
                          data: MD.markdownToHtml(event.description),
                          onLinkTap: (url, map, element) {
                            if (url != null) {
                              SystemServices().launchURL(url);
                            }
                          },
                          style: {
                            "body": Style(
                              fontSize: FontSize(Theme.of(context).textTheme.bodyLarge?.fontSize ?? 14.0),
                            ),
                            "a": Style(
                              color: Colors.blue,
                              textDecoration: TextDecoration.underline,
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
                          ],
                        ))
                    : const SizedBox.shrink()
              ]),
            ),
          ],
        ),
      ),
      floatingActionButton: (context.watch<UserProvider>().canEdit)
          ? FloatingActionButton(
              onPressed: () {
                context.go("/events/${event!.id}/edit");
              },
              child: const Icon(Icons.edit),
            )
          : const SizedBox(),
    );
  }
}
