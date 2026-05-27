import 'dart:async'; // <--- Add this line
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:scenickazatva_app/models/Location.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:firebase_database/firebase_database.dart';

class EventsProvider extends ChangeNotifier {
  StreamSubscription<DatabaseEvent>? _eventsSubscription;
  StreamSubscription<DatabaseEvent>? _locationsSubscription;
  Map<DateTime, List<Event>> _mappedEvents = {};
  List<Event> _events = [Event()];
  List<Location> _venues = [Location()];
  DateTime _selectedDay = DateTime.now();
  bool _loading = false;

  EventsProvider() {
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _locationsSubscription?.cancel();
    super.dispose();
  }

  DateTime get selectedDay => _selectedDay;

  Map<DateTime, List> get mappedEvents => _mappedEvents;

  List<Event> get events => _events != [] ? _events : [];

  List<Location> get venues => _venues;

  bool get loading => _loading;


  List<Event> get selectedEvents {
    return _events.where((event) {
      return event.startTime?.year == _selectedDay.year &&
          event.startTime?.month == _selectedDay.month &&
          event.startTime?.day == _selectedDay.day;
    }).toList();
  }

  void setSelectedDay(DateTime day) {
    _selectedDay = day;
  }

  String? _lastFetchedId;

  void updateFromSettings(AppSettingsProvider settingsProvider) {
    if (settingsProvider.isInitialized) {
      String newFestivalId = settingsProvider.defaultfestival;

      // Check if the ID changed to prevent infinite loops
      if (newFestivalId.isNotEmpty && newFestivalId != _lastFetchedId) {
        _lastFetchedId = newFestivalId;

        // Wrap both calls inside the same microtask
        Future.microtask(() {
          fetchAllEvents(newFestivalId);
          fetchLocations(newFestivalId);
        });
      }
    }
  }


  void fetchAllEvents(String festivalId) async { // returns a bool
    await _eventsSubscription?.cancel();
    setLoading(true);
    //FirebaseDatabase database = FirebaseDatabase.instance;
    DatabaseReference eventsdb = FirebaseDatabase.instance.ref("festivals/$festivalId/events");


    if (!kIsWeb){eventsdb.keepSynced(true);}


// Subscribe to the stream!
_eventsSubscription = eventsdb.onValue.listen((DatabaseEvent event) {
//    stream.listen((DatabaseEvent event){
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final List<Event> fetchedEvents = data.values.map((e) {
          return Event.fromJson(Map<String, dynamic>.from(e as Map));
        }).toList();
        setEvents(fetchedEvents);
      }
/*
      List<dynamic> _events = [];
      Map validMap = json.decode(json.encode(event.snapshot.value));
      for (var e in validMap.values){
        _events.add(e);
      }
     setEvents(
        _events.map((model) => Event.fromJson(model)).toList(),
      );*/
    });
  }

  void setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }
/*
  void setEvents(List<Event> events) async {
    _events = events;
    _mappedEvents.clear();
    //Todo: Refactor to not have so many lists... and do it in parent method fetchEventsForArrangement
    _events.forEach((event) async {
      var key = DateTime(
          event.startTime!.year, event.startTime!.month, event.startTime!.day);

      if (!_mappedEvents.containsKey(key)) {
        _mappedEvents.putIfAbsent(key, () => [event]);
      } else {
        _mappedEvents[key]!.addAll([event]);
      }
    });

    _events.sort((a, b) => a.startTime!.compareTo(b.startTime!));
    notifyListeners();
  }
*/
  void setEvents(List<Event> events) { // Removed async, not needed here
    _events = events;
    _mappedEvents.clear();

    for (var event in _events) {
      if (event.startTime == null) continue;

      var key = DateTime(
          event.startTime!.year,
          event.startTime!.month,
          event.startTime!.day
      );

      _mappedEvents.putIfAbsent(key, () => []).add(event);
    }

    _events.sort((a, b) => a.startTime!.compareTo(b.startTime!));
    notifyListeners();
  }

  void fetchLocations(String festivalId) async {setLoading(true);

  final locationdb = FirebaseDatabase.instance.ref("festivals/$festivalId/locations");

  if(!kIsWeb){locationdb.keepSynced(true);}

  // CANCEL the old subscription before starting a new one
  await _locationsSubscription?.cancel();

  // Assign to the subscription variable
  _locationsSubscription = locationdb.onValue.listen((DatabaseEvent venue) {
    final data = venue.snapshot.value as Map<dynamic, dynamic>?;
    if (data != null) {
      List<Location> list = data.values.map((model) {
        return Location.fromData(Map<String, dynamic>.from(model as Map));
      }).toList();
      setLocations(list);
    }
  });
  }

  IconData getLocationIcon(loc) {
    Location _venue = Location();
    var foundVenues = _venues.where((element) => element.id == loc);

    if (foundVenues.isNotEmpty) {
      _venue = foundVenues.first;
    }

    // Check if icon is empty or not a number to prevent crash
    if (_venue.icon.isEmpty) return Icons.location_on;

    try {
      return IconData(int.parse(_venue.icon), fontFamily: 'MaterialIcons');
    } catch (e) {
      return Icons.location_on; // Fallback icon
    }
  }

  Color getLocationColor(loc) {
    // Use .firstWhereOrNull logic to be cleaner
    final venue = _venues.cast<Location?>().firstWhere(
            (e) => e?.id == loc,
        orElse: () => null
    );

    String colorString = (venue?.color ?? "").isEmpty ? "FF000000" : venue!.color;

    try {
      return Color(int.parse(colorString, radix: 16));
    } catch (e) {
      return Colors.black; // Safe fallback
    }
  }

  // Optimized and safer version of your getLocationName
  String getLocationName(dynamic loc) {
    // Search for the venue once
    final venue = _venues.cast<Location?>().firstWhere(
            (e) => e?.id == loc,
        orElse: () => null
    );

    // Return the name if found, or a fallback string if not
    return venue?.displayName ?? "Neznáme miesto";
  }

  void validateSelectedDay(DateTime start, DateTime end) {
    if (_selectedDay.isBefore(start) || _selectedDay.isAfter(end)) {
      _selectedDay = start;
      notifyListeners();
    }
  }

  void updateEvent(Event _e) async {
    try {
      setLoading(true);
      // Use the ID we already have in the provider
      String? _festival = _lastFetchedId;

      if (_festival != null && _e.id.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref("festivals/$_festival/events/${_e.id}/")
            .update(_e.toJson());
        print("Firebase save success");
      }
    } catch (error) {
      print("Firebase update error: $error");
    } finally {
      setLoading(false);
    }
  }


  void setLocations(List<Location> list) {
    _venues = list;
    notifyListeners();
    setLoading(false);
  }


}
