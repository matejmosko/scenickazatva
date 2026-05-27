import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as MD;
import 'package:go_router/go_router.dart';

class CalendarView extends StatefulWidget {
  CalendarView({Key? key, this.title = ""}) : super(key: key);
  final String title;

  @override
  _CalendarViewState createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> with TickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime? _selectedDay;
  DateTime? _focusedDay;
  AnimationController? _animationController;

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
    return eventsProvider.events.where((event) => isSameDay(event.startTime, day)).toList();
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
    final festivalProvider = Provider.of<FestivalProvider>(context);
    final fest = festivalProvider.festival;

    // Safety: If the app opens and 'today' is outside the festival,
    // focus on the festival start date instead.
    print("DEBUG: Festival start date: ${fest.startDate}");
    //debugPrint("DEBUG: FestivalProvider has this data: ${festivalProvider.festival}");
    inspect(festivalProvider.festival);
    print("DEBUG: Focused day: ${_focusedDay}");
    print("DEBUG: Selected day: ${_selectedDay}");
    if (fest.startDate != null && _focusedDay!.isBefore(fest.startDate!)) {
      _focusedDay = fest.startDate;
      _selectedDay = fest.startDate;
    }
    else if (fest.endDate != null && _focusedDay!.isAfter(fest.endDate!)) {
      _focusedDay = fest.startDate; // Or fest.endDate
      _selectedDay = fest.startDate;
    }
    print("DEBUG2: Festival start date: ${fest.startDate}");
    print("DEBUG2: Focused day: ${_focusedDay}");
    print("DEBUG2: Selected day: ${_selectedDay}");

    return Column(
      children: <Widget>[
        _buildTableCalendarWithBuilders(festivalProvider, fest),
        Expanded(child: _buildEventList(fest)),
      ],
    );
  }

  Widget _buildTableCalendarWithBuilders(FestivalProvider festivalProvider, Festival fest) {
    if (festivalProvider.loading && fest.title.isEmpty) {
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
          defaultTextStyle: TextStyle(color: festivalProvider.foregroundColor),
          weekendTextStyle: TextStyle(color: festivalProvider.foregroundColor),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: festivalProvider.foregroundColor),
          weekendStyle: TextStyle(color: festivalProvider.foregroundColor),
        ),
        calendarBuilders: CalendarBuilders(
          selectedBuilder: (context, date, _) => Container(
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(shape: BoxShape.rectangle, color: festivalProvider.festivalForegroundColor),
            child: Center(child: Text('${date.day}', style: TextStyle(color: festivalProvider.festivalBackgroundColor))),
          ),
          todayBuilder: (context, date, _) => Container(
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              border: Border.all(color: festivalProvider.festivalForegroundColor, width: 2.0),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Center(child: Text('${date.day}', style: TextStyle(color: festivalProvider.foregroundColor))),
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

  Widget _buildEventsMarker(int count, FestivalProvider fp) {
    return Container(
      width: 16, height: 16,
      decoration: BoxDecoration(color: fp.festivalThirdColor, shape: BoxShape.rectangle),
      child: Center(child: Text('$count', style: TextStyle(color: fp.festivalForegroundColor, fontSize: 10))),
    );
  }

  Widget _buildEventList(Festival festival) {
    final eventsProvider = Provider.of<EventsProvider>(context);
    final filteredEvents = eventsProvider.events.where((e) => isSameDay(e.startTime, _selectedDay)).toList();

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

    return GestureDetector(
      onTap: () => context.go("/events/${event.id}"),
      child: Card(
        shape: RoundedRectangleBorder(
          side: playing ? const BorderSide(color: Colors.black, width: 2.0) : BorderSide.none,
          borderRadius: BorderRadius.circular(5.0),
        ),
        color: event.type == "offprogram" ? fp.offProgramColor : event.type == "partner" ? fp.partnerProgramColor : fp.mainProgramColor,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: 60,
                child: Column(
                  children: [
                    Icon(eventsProvider.getLocationIcon(location), color: eventsProvider.getLocationColor(location), size: 26),
                    Text(location, style: TextStyle(color: eventsProvider.getLocationColor(location)), textAlign: TextAlign.center),
                    Text(startTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title ?? '', style: Theme.of(context).textTheme.titleMedium),
                  LimitedBox(
                    maxHeight: 70,
                    child: Html(data: MD.markdownToHtml(event.description ?? '')),
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
        errorBuilder: (context, _, __) => Image(image: FirebaseImageProvider(FirebaseUrl(fallbackUrl))),
      ),
    );
  }
}