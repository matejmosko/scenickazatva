import 'package:flutter/material.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';

// Calendar view displays data from EventsProvider in a calendar. It observes all Providers to be able to do that.

class CalendarView extends StatefulWidget {
  CalendarView({Key? key, this.title = ""}) : super(key: key);
  final String title;

  @override
  _CalendarViewState createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime? _selectedDay;
  DateTime? _focusedDay;
  AnimationController? _animationController;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  List<dynamic> _fetchEvents(DateTime day) {
    // listen: false is required here because it's called during build
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    return eventsProvider.filteredMappedEvents[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    // Sync the selection to the provider so other parts of the app know which day we are looking at
    Provider.of<EventsProvider>(context, listen: false).setSelectedDay(selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final festivalProvider = Provider.of<FestivalProvider>(context);
    final fest = festivalProvider.festival;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Detect if our local state needs to adjust to the new festival bounds
    bool dayChanged = false;

    if (fest.startDate != null && _focusedDay!.isBefore(fest.startDate!) && !isSameDay(_focusedDay, fest.startDate)) {
      _focusedDay = fest.startDate;
      _selectedDay = fest.startDate;
      dayChanged = true;
    }
    else if (fest.endDate != null && _focusedDay!.isAfter(fest.endDate!) && !isSameDay(_focusedDay, fest.endDate)) {
      _focusedDay = fest.startDate;
      _selectedDay = fest.startDate;
      dayChanged = true;
    }

    // 2. Fix: If the day changed due to a festival switch, sync it to the EventsProvider safely
    if (dayChanged && _selectedDay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<EventsProvider>(context, listen: false).setSelectedDay(_selectedDay!);
        }
      });
    }

    return Column(
      children: <Widget>[
        _buildTableCalendarWithBuilders(festivalProvider, fest),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Row(
            children: [
              Expanded(child: _buildLocationDropdown()),
              const SizedBox(width: 8),
              Text(
                "Iba obľúbené",
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black,
                  fontSize: 12,
                ),
              ),
              Switch(
                value: _showFavoritesOnly,
                activeThumbColor: isDark ? Colors.white54 : Colors.black,
                onChanged: (val) {
                  setState(() {
                    _showFavoritesOnly = val;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(child: _buildEventList(fest)),
      ],
    );
  }

  Widget _buildTableCalendarWithBuilders(FestivalProvider festivalProvider, Festival fest) {
    final eventsProvider = Provider.of<EventsProvider>(context);
    if ((festivalProvider.loading || eventsProvider.loading) && fest.title.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      ));
    }

    return Container(
      color: festivalProvider.festivalBackgroundColor,
      child: TableCalendar(
        locale: 'sk_SK',
        firstDay: fest.startDate ?? DateTime.now().subtract(const Duration(days: 365)),
        lastDay: fest.endDate ?? DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay!,
        headerVisible: false,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        eventLoader: _fetchEvents,
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {CalendarFormat.week: 'Týždeň'},
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          defaultTextStyle: TextStyle(color: festivalProvider.foregroundColor, fontSize: 14.0),
          weekendTextStyle: TextStyle(color: festivalProvider.foregroundColor, fontSize: 14.0),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: festivalProvider.foregroundColor, fontSize: 12.0),
          weekendStyle: TextStyle(color: festivalProvider.foregroundColor, fontSize: 12.0),
        ),
        calendarBuilders: CalendarBuilders(
          selectedBuilder: (context, date, _) => Container(
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: festivalProvider.festivalForegroundColor,
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: festivalProvider.festivalBackgroundColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                ),
              ),
            ),
          ),
          todayBuilder: (context, date, _) => Container(
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: festivalProvider.festivalForegroundColor,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: festivalProvider.foregroundColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                ),
              ),
            ),
          ),
          markerBuilder: (context, date, events) {
            if (events.isNotEmpty) {
              return Positioned(right: 0, bottom: 0, child: _buildEventsMarker(events.length, festivalProvider));
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildLocationDropdown() {
    final eventsProvider = Provider.of<EventsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (eventsProvider.venues.isEmpty) return const SizedBox.shrink();


    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: eventsProvider.selectedLocationId,
        isExpanded: true,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black,
          fontSize: 14,
          fontFamily: 'Space Grotesk',
        ),
        hint: const Text("Všetky miesta"),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text("Všetky miesta"),
          ),
          ...eventsProvider.venues.map((venue) {
            return DropdownMenuItem<String?>(
              value: venue.id,
              child: Row(
                children: [
                  Icon(
                    eventsProvider.getLocationIcon(venue.id),
                    size: 18,
                    color: eventsProvider.getLocationColor(venue.id),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(venue.displayName, overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }).toList(),
        ],
        onChanged: (String? value) {
          eventsProvider.setSelectedLocation(value);
        },
      ),
    );
  }

  Widget _buildEventsMarker(int count, FestivalProvider fp) {
    return Container(
      width: 16, height: 16,
      decoration: BoxDecoration(color: fp.festivalThirdColor, shape: BoxShape.rectangle),
      child: Center(child: Text('$count', style: TextStyle(color: fp.festivalForegroundColor, fontSize: 10))),
    );
  }

  Widget _buildEventList(Festival festival) {
    final eventsProvider = Provider.of<EventsProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    
    var filteredEvents = eventsProvider.selectedEvents;

    if (_showFavoritesOnly) {
      filteredEvents = filteredEvents.where((e) => userProvider.isFavorite(festival.id, e.id)).toList();
    }

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 500),
      child: filteredEvents.isEmpty
          ? const Center(child: Text("Žiadne podujatia na tento deň"))
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filteredEvents.length,
        itemBuilder: (context, index) => EventListItem(event: filteredEvents[index], festival: festival),
      ),
    );
  }
}

class EventListItem extends StatelessWidget {
  final dynamic event; // Should ideally be Event type
  final Festival festival;

  const EventListItem({Key? key, required this.event, required this.festival}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat("HH:mm").format(event.startTime);
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
                    Icon(eventsProvider.getLocationIcon(location), color: eventsProvider.getLocationColor(location), size: 26),
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
                      style: Theme.of(context).textTheme.bodyMedium,
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
      width: 120, height: 120,
      child: Image(
        image: FirebaseImageProvider(FirebaseUrl(imageUrl.isNotEmpty ? imageUrl : fallbackUrl)),
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => Image(image: FirebaseImageProvider(FirebaseUrl(fallbackUrl)),errorBuilder:(context, _, __) => Image.asset(
            'assets/images/icon512.png')),
      ),
    );
  }
}