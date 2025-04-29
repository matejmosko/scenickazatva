import 'package:flutter/material.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:scenickazatva_app/requests/api.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as MD;
import 'package:go_router/go_router.dart';

class CalendarView extends StatefulWidget {
  CalendarView({Key? key, this.title = ""}) : super(key: key);

  final String title;

  @override
  _CalendarViewState createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView>
    with TickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime? _selectedDay;
  DateTime _rangeStart = DateTime.utc(2024, 8, 28);
  DateTime _rangeEnd = DateTime.utc(2025, 12, 31);
  DateTime? _focusedDay;
  // static var _calendarKeyCount = 0;
  AnimationController? _animationController;
  Festival festival = Festival();
  List venues = [];
  // List events;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _selectedDay = _focusedDay;

    _animationController?.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  List<Event> _fetchEvents(DateTime day){
    EventsProvider eventsProvider =
        Provider.of<EventsProvider>(context, listen: false);

    final events = eventsProvider.events;
    return events.where((event) {
      return event.startTime?.year == day.year &&
          event.startTime?.month == day.month &&
          event.startTime?.day == day.day;
    }).toList();
  }

  Future<Festival> getFestival() async {
    FestivalProvider festivalProvider =
        Provider.of<FestivalProvider>(context, listen: false);
    festival = await festivalProvider.fetchFestival();

    if (_focusedDay == null) {setDefaultDay();}

    //_calendarKeyCount += 1;
    return festival;
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    print('CALLBACK: _onDaySelected');
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      setSelectedDay(selectedDay);
    });
  }

  void setDefaultDay(){
    final FestivalProvider festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    festivalProvider.fetchFestival();
    festival = festivalProvider.festival;

    _rangeStart = festival.startDate ?? _rangeStart;
    _rangeEnd = festival.endDate ?? _rangeEnd;

    _focusedDay = DateTime.now();
    _focusedDay =
    (_focusedDay!.isBefore(_rangeStart) || _focusedDay!.isAfter(_rangeEnd))
        ? _rangeStart
        : _focusedDay;
    _selectedDay = _focusedDay;
  }

  void setSelectedDay(DateTime day) {
    final EventsProvider eventsProvider =
        Provider.of<EventsProvider>(context, listen: false);
    eventsProvider.setSelectedDay(day);
  }

  @override
  Widget build(BuildContext context) {
    final FestivalProvider festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    festivalProvider.fetchFestival();
    festival = festivalProvider.festival;

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        Container(
          child: _buildTableCalendarWithBuilders(),
          /*decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                blurRadius: 1.0, // has the effect of softening the shadow
                spreadRadius: 5.0, // has the effect of extending the shadow
              )
            ],
          ),*/
        ),
        Expanded(child: _buildEventList()),
      ],
    );
  }

  // More advanced TableCalendar configuration (using Builders & Styles)
  Widget _buildTableCalendarWithBuilders() {
    final FestivalProvider festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    festivalProvider.fetchFestival();
    return Container(
      color: festivalProvider.festivalBackgroundColor,
      child: FutureBuilder(
          future: getFestival(),
          builder: (BuildContext context, AsyncSnapshot<Festival> snapshot) {
            if (snapshot.hasData) {
              return TableCalendar(
                locale: 'sk_SK',
                firstDay: snapshot.data!.startDate ?? _rangeStart,
                lastDay: snapshot.data!.endDate ?? _rangeEnd,
                focusedDay: _focusedDay!,
                headerVisible: false,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: _onDaySelected,
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    // Call `setState()` when updating calendar format
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  // No need to call `setState()` here
                  _focusedDay = focusedDay;
                },
                eventLoader: _fetchEvents,
                calendarFormat: _calendarFormat,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableGestures: AvailableGestures.all,
                availableCalendarFormats: const {
                  CalendarFormat.week: 'Týždeň',
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: true,
                  outsideTextStyle: TextStyle(color: festivalProvider.foregroundColor),
                  defaultTextStyle: TextStyle(color: festivalProvider.foregroundColor),
                  disabledTextStyle: TextStyle(color: festivalProvider.foregroundColor),
                  weekendTextStyle: TextStyle(color: festivalProvider.foregroundColor),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: festivalProvider.foregroundColor,
                    ),
                    weekendStyle: TextStyle(
                      color: festivalProvider.foregroundColor,
                    )),
                calendarBuilders: CalendarBuilders(
                  selectedBuilder: (context, date, _) {
                    return FadeTransition(
                      opacity: Tween(begin: 0.0, end: 1.0)
                          .animate(_animationController!),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                            shape: BoxShape.rectangle, color: festivalProvider.festivalForegroundColor),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            /*style: TextStyle(
                                  color: Theme.of(context).colorScheme.onInverseSurface)
                              .copyWith(fontSize: 16.0),*/
                          ),
                        ),
                      ),
                    );
                  },
                  todayBuilder: (context, date, _) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(width: 3.0),
                        borderRadius: BorderRadius.all(Radius.circular(
                                4.0) //                 <--- border radius here
                            ),
                      ),
                      width: 100,
                      height: 100,
                      child: Center(
                        child: Text(
                          '${date.day}',
                          /* style: TextStyle().copyWith(fontSize: 16.0),*/
                        ),
                      ),
                    );
                  },
                  markerBuilder: (context, date, List events) {
                    if (events.isNotEmpty) {
                      return Positioned(
                        bottom: 0,
                        right: 0,
                        child: _buildEventsMarker(date, events),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  },
                ),
              );
            } else if (snapshot.hasError) {
              return Row(children: [
                Text(
                  "Nepodarilo sa načítať informácie o festivale. Skontrolujte svoje pripojenie k internetu.",
                ),
              ]);
            } else

              // Future hasn't finished yet, return a placeholder
              return Row(children: [
                Text(
                  "Načítavam...",
                ),
              ]);
          }),
    );
  }

  Widget _buildEventsMarker(DateTime date, List events) {
    final FestivalProvider festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    festivalProvider.fetchFestival();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
          color: festivalProvider.festivalThirdColor, shape: BoxShape.rectangle),
      width: 16.0,
      height: 16.0,
      child: Center(
        child: Text(
          '${events.length}',
          style: TextStyle().copyWith(
            color: festivalProvider.festivalForegroundColor,
            fontSize: 10.0,
          ),
        ),
      ),
    );
  }

  Widget _buildEventList() {
    final EventsProvider eventsProvider = Provider.of<EventsProvider>(context);
    if (_selectedDay == null) {setDefaultDay();}

    return Container(
        /* decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.jpg"),
            fit: BoxFit.cover,
          )
        ),*/
        child: AnimatedOpacity(
      opacity: eventsProvider.events.length > 0 ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500),
      child: ListView(
        padding: EdgeInsets.all(8),
        children: _fetchEvents(_selectedDay!)
            .map((event) => EventListItem(event: event, festival: festival))
            .toList(),
      ),
    ));
  }
}

class EventListItem extends StatelessWidget {
  final event;
  final Festival festival;

  const EventListItem({Key? key, @required this.event, required this.festival})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
//    String Formatting
    //Start & End-time
    final startTime = event.startTime != null
        ? new DateFormat("HH:mm").format(event.startTime)
        : '';
    /*final endTime = event.endTime != null
        ? new DateFormat("HH:mm").format(event.endTime)
        : '';*/

    //Location
    final location = event.location != null ? "${event.location}" : '';
    /*final description = event.description != null
        ? event.description.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
        : '';*/

    final playing = (event.startTime.isAfter(DateTime.now()) &&
            event.endTime.isBefore(DateTime.now()))
        ? true
        : false; // Check if the event is currently on.

    final EventsProvider eventsProvider = Provider.of<EventsProvider>(context);
    final FestivalProvider festivalProvider =
        Provider.of<FestivalProvider>(context);
    print(festivalProvider.festival.logo);

    return GestureDetector(
        child: Card(
            shape: playing
                ? RoundedRectangleBorder(
                    side: BorderSide(
                      color: Colors.black,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(5.0),
                  )
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
            color: event.type == "offprogram"
                ? festivalProvider.offProgramColor
                : event.type == "partner"
                    ? festivalProvider.partnerProgramColor
                    : festivalProvider.mainProgramColor,
            child: Row(children: <Widget>[
              Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                    width: 60,
                    child: Column(
                      /*crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,*/
                      children: <Widget>[
                        Icon(eventsProvider.getLocationIcon(event.location),
                            color:
                                eventsProvider.getLocationColor(event.location),
                            size: 26),
                        Text("$location",
                            style: TextStyle(
                                color: eventsProvider
                                    .getLocationColor(event.location)),
                            textAlign: TextAlign.center),
                        Text("$startTime"),
                      ],
                    )),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text("${event.title ?? ''}",
                        style: Theme.of(context).textTheme.displaySmall),
                    LimitedBox(
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black, Colors.transparent],
                          ).createShader(bounds);
                        },
                        child: Html(data: MD.markdownToHtml(event.description)),
                      ),
                      maxHeight: 70,
                    )
                  ],
                ),
              ),
              Container(
                width: 120.0,
                height: 120.0,
                child: event.image != ""
                    ? Image(
                        image: FirebaseImageProvider(
                          FirebaseUrl(event.image),
                        ),
                        fit: BoxFit.cover,
                        height: double.infinity,
                        width: double.infinity,
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
                          return Image(
                              image: FirebaseImageProvider(
                            FirebaseUrl(festival.logo),
                          ));

                          // Image.asset('assets/images/logo_sz.png');
                        },
                      )
                    : Image(
                        image: FirebaseImageProvider(
                        FirebaseUrl(festival.logo),
                      )),
              ),
            ])),
        onTap: () {
          Analytics().sendEvent(event.title);
          context.go("/events/" + event.id);
/*        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailPage(
              eventId: event.id,
            ),
          ),
        );*/
        });
  }
}
