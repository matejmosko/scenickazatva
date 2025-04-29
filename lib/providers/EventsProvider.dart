//import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:scenickazatva_app/models/Location.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scenickazatva_app/requests/api.dart';

class EventsProvider extends ChangeNotifier {
  Map<DateTime, List<Event>> _mappedEvents = {};
  List<Event> _events = [Event()];
  List<Location> _venues = [Location()];
  DateTime _selectedDay = DateTime.now();
  bool _loading = false;

  EventsProvider() {
    fetchAllEvents();
    fetchLocations();
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


  void fetchAllEvents() async { // returns a bool
    setLoading(true);
    //FirebaseDatabase database = FirebaseDatabase.instance;
    //database.setPersistenceEnabled(true);
    String festival = await API().getDefaultFestival();
    DatabaseReference eventsdb = FirebaseDatabase.instance.ref("festivals/$festival/events");
    Stream<DatabaseEvent> stream = eventsdb.onValue;

    if (!kIsWeb){eventsdb.keepSynced(true);}
    // Get the Stream

// Subscribe to the stream!
    stream.listen((DatabaseEvent event){

      List<dynamic> _events = [];
      Map validMap = json.decode(json.encode(event.snapshot.value));
      for (var e in validMap.values){
        _events.add(e);
      }
     setEvents(
        _events.map((model) => Event.fromJson(model)).toList(),
      );
    });
  }

  void setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }

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

  void /*Future<List<InfoPost>>*/ fetchLocations() async {
    setLoading(true);
    FirebaseDatabase database = FirebaseDatabase.instance;
    if(!kIsWeb){database.setPersistenceEnabled(true);}


    String festival = await API().getDefaultFestival();
    final locationdb = FirebaseDatabase.instance.ref("festivals/$festival/locations");
    if(!kIsWeb){locationdb.keepSynced(true);}
    // Get the Stream
    Stream<DatabaseEvent> stream = locationdb.onValue;

// Subscribe to the stream!
    stream.listen((DatabaseEvent venue) {
      List<dynamic> list = [];
      Map validMap = json.decode(json.encode(venue.snapshot.value));
      for (var e in validMap.values){
        list.add(e);
      }
      setLocations(
          _venues = list.map((model) => Location.fromData(model)).toList()
      );
    });
  }

  IconData getLocationIcon(loc){
    Location _venue = Location();
    if (_venues.where((element) => (element.id == loc)).length > 0){
      _venue = _venues.where((element) => (element.id == loc))
          .toList()[0];
    }
    return IconData(int.parse(_venue.icon), fontFamily: 'MaterialIcons');
  }

  Color getLocationColor(loc){
    Location _venue = Location();
    if (_venues.where((element) => (element.id == loc)).length > 0){
      _venue = _venues.where((element) => (element.id == loc))
          .toList()[0];
    }
    String colorString = _venue.color;
    int colorInt = int.parse(colorString, radix: 16);
    Color color = new Color(colorInt);
    return color;
  }

  String getLocationName(loc){
    Location _venue = Location();
    if (_venues.where((element) => (element.id == loc)).length > 0) {
      _venue = _venues.where((element) => (element.id == loc))
          .toList()[0];
    }
    String name = _venue.displayName;
    return name;
  }

  void updateEvent(Event _e) async{
    setLoading(true);
    //FirebaseDatabase database = FirebaseDatabase.instance;
    //database.setPersistenceEnabled(true);
    String _festival = await API().getDefaultFestival();
    if (_e.id != "") {
      //String _key = DateFormat("dd-MM-HHmm-", "sk_SK").format(_e.startTime!)+_e.id;
      String _key = _e.id;
      FirebaseDatabase.instance
          .ref("festivals/$_festival/events/$_key/")
          .update(_e.toJson())
          .then((_) {
        print("Firebase save success");
      }).catchError((error) {
        print(error);
      });
    }
  }


  void setLocations(List<Location> list) {
    _venues = list;
    notifyListeners();
    setLoading(false);
  }


}
