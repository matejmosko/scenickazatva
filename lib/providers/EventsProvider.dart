import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:scenickazatva_app/models/Location.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:firebase_database/firebase_database.dart';

/// Provider responsible for fetching, storing and managing festival events.
/// Handles real-time synchronization with Firebase and role-based editing permissions.
class EventsProvider extends ChangeNotifier {
  StreamSubscription<DatabaseEvent>? _eventsSubscription;
  StreamSubscription<DatabaseEvent>? _locationsSubscription;
  
  // Events grouped by day for the calendar view
  Map<DateTime, List<Event>> _mappedEvents = {};
  Map<DateTime, List<Event>> _filteredMappedEvents = {};
  
  // Flat list of all events for the current festival
  List<Event> _events = [];
  
  // List of venues/locations for the current festival
  List<Location> _venues = [];
  
  DateTime _selectedDay = DateTime.now();
  String? _selectedLocationId;
  bool _loading = true;
  bool _canEdit = false;

  EventsProvider();

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _locationsSubscription?.cancel();
    super.dispose();
  }

  // Getters
  DateTime get selectedDay => _selectedDay;
  String? get selectedLocationId => _selectedLocationId;
  Map<DateTime, List> get mappedEvents => _mappedEvents;
  Map<DateTime, List<Event>> get filteredMappedEvents => _filteredMappedEvents;
  List<Event> get events => _events;
  List<Location> get venues => _venues;
  bool get loading => _loading;

  /// Returns events scheduled for the currently selected day in the calendar,
  /// respects the active location filter.
  List<Event> get selectedEvents {
    return _events.where((event) {
      final isDay = event.startTime?.year == _selectedDay.year &&
          event.startTime?.month == _selectedDay.month &&
          event.startTime?.day == _selectedDay.day;
      
      final isLocation = _selectedLocationId == null || event.location == _selectedLocationId;
      
      return isDay && isLocation;
    }).toList();
  }

  void setSelectedDay(DateTime day) {
    _selectedDay = day;
    notifyListeners();
  }

  void setSelectedLocation(String? locationId) {
    _selectedLocationId = locationId;
    _updateFilteredMappedEvents();
    notifyListeners();
  }

  void _updateFilteredMappedEvents() {
    _filteredMappedEvents.clear();
    for (var entry in _mappedEvents.entries) {
      final filtered = entry.value.where((event) => 
        _selectedLocationId == null || event.location == _selectedLocationId
      ).toList();
      if (filtered.isNotEmpty) {
        _filteredMappedEvents[entry.key] = filtered;
      }
    }
  }

  /// Updates editing permissions based on the logged-in user's role
  void updateFromUser(bool canEdit) {
    _canEdit = canEdit;
  }

  String? _lastFetchedId;

  /// Reaction to AppSettings changes - triggers re-fetch if festival ID changes
  void updateFromSettings(AppSettingsProvider settingsProvider) {
    if (settingsProvider.isInitialized) {
      String newFestivalId = settingsProvider.defaultfestival;

      // Re-fetch if ID changed OR if initial load is needed
      if (newFestivalId.isNotEmpty && (newFestivalId != _lastFetchedId || (_events.isEmpty && !_loading))) {
        _lastFetchedId = newFestivalId;

        Future.microtask(() {
          fetchAllEvents(newFestivalId);
          fetchLocations(newFestivalId);
        });
      }
    }
  }

  /// Subscribes to the real-time stream of events for a specific festival
  void fetchAllEvents(String festivalId) async {
    await _eventsSubscription?.cancel();
    setLoading(true);
    
    DatabaseReference eventsdb = FirebaseDatabase.instance.ref("festivals/$festivalId/events");

    // Offline support
    if (!kIsWeb) {
      eventsdb.keepSynced(true);
    }

    _eventsSubscription = eventsdb.onValue.listen((DatabaseEvent event) {
      final Object? rawData = event.snapshot.value;
      if (rawData != null) {
        Iterable? items;
        if (rawData is Map) {
          items = rawData.values;
        } else if (rawData is List) {
          items = rawData;
        }

        if (items != null) {
          final List<Event> fetchedEvents = items
              .where((e) => e != null)
              .map((e) => Event.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          setEvents(fetchedEvents);
        } else {
          setEvents([]);
        }
      } else {
        setEvents([]);
      }
    }, onError: (err) {
      debugPrint("Firebase Events Error: $err");
      setLoading(false);
    });
  }

  void setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }

  /// Updates local state with new events, including grouping by day and sorting
  void setEvents(List<Event> events) {
    // Safety check: Filter out corrupted data
    _events = events.where((e) => e.startTime != null).toList();
    _mappedEvents.clear();

    for (var event in _events) {
      var key = DateTime(
          event.startTime!.year,
          event.startTime!.month,
          event.startTime!.day
      );

      _mappedEvents.putIfAbsent(key, () => []).add(event);
    }

    // Always keep events chronologically ordered
    _events.sort((a, b) => a.startTime!.compareTo(b.startTime!));
    _updateFilteredMappedEvents();
    setLoading(false);
  }

  /// Fetches venue data for the current festival
  void fetchLocations(String festivalId) async {
    final locationdb = FirebaseDatabase.instance.ref("festivals/$festivalId/locations");

    if (!kIsWeb) {
      locationdb.keepSynced(true);
    }

    await _locationsSubscription?.cancel();

    _locationsSubscription = locationdb.onValue.listen((DatabaseEvent venue) {
      final Object? rawData = venue.snapshot.value;
      if (rawData != null) {
        Iterable? items;
        if (rawData is Map) {
          items = rawData.values;
        } else if (rawData is List) {
          items = rawData;
        }

        if (items != null) {
          List<Location> list = items
              .where((e) => e != null)
              .map((model) => Location.fromData(Map<String, dynamic>.from(model as Map)))
              .toList();
          setLocations(list);
        } else {
          setLocations([]);
        }
      } else {
        setLocations([]);
      }
    });
  }

  /// Helper: Gets the Material Icon for a specific location ID
  IconData getLocationIcon(loc) {
    Location? venue;
    var foundVenues = _venues.where((element) => element.id == loc);

    if (foundVenues.isNotEmpty) {
      venue = foundVenues.first;
    }

    if (venue == null || venue.icon.isEmpty) return Icons.location_on;

    try {
      return IconData(int.parse(venue.icon), fontFamily: 'MaterialIcons');
    } catch (e) {
      return Icons.location_on;
    }
  }

  /// Helper: Gets the brand color for a specific location
  Color getLocationColor(loc) {
    final venue = _venues.cast<Location?>().firstWhere(
            (e) => e?.id == loc,
        orElse: () => null
    );

    String colorString = (venue?.color ?? "").isEmpty ? "FF000000" : venue!.color;

    try {
      return Color(int.parse(colorString, radix: 16));
    } catch (e) {
      return Colors.black;
    }
  }

  /// Helper: Gets the human-readable name of a location
  String getLocationName(dynamic loc) {
    final venue = _venues.cast<Location?>().firstWhere(
            (e) => e?.id == loc,
        orElse: () => null
    );

    return venue?.displayName ?? "Neznáme miesto";
  }

  /// Blocks/Updates an existing event in Firebase (Admin/Editor only)
  void updateEvent(Event _e) async {
    if (!_canEdit) {
      debugPrint("Unauthorized update attempt blocked");
      return;
    }
    try {
      setLoading(true);
      String? _festival = _lastFetchedId;

      if (_festival != null && _e.id.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref("festivals/$_festival/events/${_e.id}/")
            .update(_e.toJson());
        debugPrint("Firebase save success");
      }
    } catch (error) {
      debugPrint("Firebase update error: $error");
    } finally {
      setLoading(false);
    }
  }

  /// Pushes a new event to Firebase (Admin/Editor only)
  Future<String?> createEvent(Event e) async {
    if (!_canEdit) {
      debugPrint("Unauthorized create attempt blocked");
      return null;
    }
    try {
      setLoading(true);
      String? _festival = _lastFetchedId;

      if (_festival != null) {
        DatabaseReference newEventRef = FirebaseDatabase.instance
            .ref("festivals/$_festival/events")
            .push();
        e.id = newEventRef.key ?? "";
        await newEventRef.set(e.toJson());
        debugPrint("Firebase create success: ${e.id}");
        return e.id;
      }
    } catch (error) {
      debugPrint("Firebase create error: $error");
    } finally {
      setLoading(false);
    }
    return null;
  }

  /// Removes an event from Firebase (Admin/Editor only)
  void deleteEvent(String eventId) async {
    if (!_canEdit) {
      debugPrint("Unauthorized delete attempt blocked");
      return;
    }
    try {
      setLoading(true);
      String? _festival = _lastFetchedId;

      if (_festival != null && eventId.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref("festivals/$_festival/events/$eventId")
            .remove();
        debugPrint("Firebase delete success");
      }
    } catch (error) {
      debugPrint("Firebase delete error: $error");
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
