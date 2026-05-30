import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/HivePreferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  StreamSubscription<DatabaseEvent>? _settingsSubscription;
  bool _initialized = false;
  List<Festival> _allFestivals = [];
  List<Festival> get allFestivals => _allFestivals;

  // Getters
  AppSettings get settings => _settings;
  String get defaultfestival => _settings.defaultfestival;
  bool get isInitialized => _initialized;


  AppSettingsProvider() {
    debugPrint("DEBUG: AppSettingsProvider constructor started");
    loadSettings();
    syncWithFirebase();
  }

  // 1. Load from Hive first (Offline First)
  Future<void> loadSettings() async {
    try {
      Preferences prefs = await Preferences.getInstance();
      if (!_initialized) {
        _settings = prefs.getAppSettings();
        _allFestivals = _settings.festivals.values.toList();
        _allFestivals.sort((a, b) => (b.startDate ?? DateTime(0)).compareTo(a.startDate ?? DateTime(0)));
        debugPrint("DEBUG: Hive load complete. ID: ${_settings.defaultfestival}");
        
        // If we have a valid-looking ID from Hive, we can mark as initialized
        if (_settings.defaultfestival.isNotEmpty && _settings.defaultfestival != "sutaze") {
           _initialized = true;
           
           // Sync link interception state with native on startup
           _syncInterceptLinksNative();
           
           notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("DEBUG: Hive error: $e");
    }
  }

  void _syncInterceptLinksNative() {
    const platform = MethodChannel('sk.panakrala.scenickazatva/settings');
    try {
      platform.invokeMethod('setInterceptLinks', {"enabled": _settings.interceptLinks});
    } catch (e) {
      debugPrint("Error syncing interceptLinks with native: $e");
    }
  }

  void syncWithFirebase() {
    DatabaseReference globalRef = FirebaseDatabase.instance.ref("appsettings");

    _settingsSubscription = globalRef.onValue.listen((event) async {
      if (event.snapshot.exists) {
        final rawData = event.snapshot.value as Map?;
        final Map<String, dynamic> convertedData = _deepConvertMap(rawData);

        // Load the global settings object
        AppSettings globalSettings = AppSettings.fromJson(convertedData);
        
        // Handle naming inconsistency in Firebase
        String selectedId = globalSettings.defaultfestival;

        // USER PREFERENCE LOGIC
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final userPrefRef = FirebaseDatabase.instance.ref("users/${user.uid}/settings/selectedFestival");
            final userSnap = await userPrefRef.get();

            if (userSnap.exists && userSnap.value != null) {
              // 2. If user has setting, use it
              selectedId = userSnap.value.toString();
              debugPrint("DEBUG: Using User Preference: $selectedId");
            } else {
              // 1. If user doesn't have setting, use global default and CREATE it for them
              debugPrint("DEBUG: Creating user preference with global default: $selectedId");
              await userPrefRef.set(selectedId);
            }
          } catch (e) {
            debugPrint("DEBUG: Error processing user preferences: $e");
          }
        }

        _settings = globalSettings;
        _settings.defaultfestival = selectedId;

        // Update _allFestivals from the master settings object which contains full metadata
        _allFestivals = _settings.festivals.values.toList();
        _allFestivals.sort((a, b) => (b.startDate ?? DateTime(0)).compareTo(a.startDate ?? DateTime(0)));

        // If the selected ID (like "sutaze") doesn't exist in our list of festivals,
// we must change it to a valid one to prevent the Dropdown from crashing.
        if (_allFestivals.isNotEmpty) {
          bool exists = _allFestivals.any((f) => f.id == _settings.defaultfestival);
          if (!exists) {
            debugPrint("DEBUG: Selected ID ${_settings.defaultfestival} not found in database. Falling back to ${_allFestivals.first.id}");
            _settings.defaultfestival = _allFestivals.first.id;
          }
        }

        // Save to Hive for next startup
        final prefs = await Preferences.getInstance();
        await prefs.saveAppSettings(_settings);

        // Sync link interception state with native
        _syncInterceptLinksNative();

        _initialized = true;
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("DEBUG: Firebase Subscription Error: $error");
    });
  }

  // 3. Dropdown Change Logic
  void changeFestival(String newId) {
    _settings.defaultfestival = newId;

    // Update Local Cache
    Preferences.getInstance().then((prefs) {
      prefs.saveAppSettings(_settings);
    });

    // Update Firebase User Profile
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseDatabase.instance
          .ref("users/${user.uid}/settings")
          .update({"selectedFestival": newId});
    }

    notifyListeners();
  }

  void updateFontSizeFactor(double newFactor) {
    _settings.fontSizeFactor = newFactor;
    
    // Update Local Cache
    Preferences.getInstance().then((prefs) {
      prefs.saveAppSettings(_settings);
    });

    // Update Firebase User Profile if needed, or just keep it local.
    // Given the request, local is probably fine, but let's sync it to Firebase
    // so it persists across devices for the same user.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseDatabase.instance
          .ref("users/${user.uid}/settings")
          .update({"fontSizeFactor": newFactor});
    }

    notifyListeners();
  }

  void updateNotificationsEnabled(bool enabled) {
    _settings.notificationsEnabled = enabled;
    Preferences.getInstance().then((prefs) => prefs.saveAppSettings(_settings));
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseDatabase.instance
          .ref("users/${user.uid}/settings")
          .update({"notificationsEnabled": enabled});
    }
    notifyListeners();
  }

  void updateRemindersEnabled(bool enabled) {
    _settings.remindersEnabled = enabled;
    Preferences.getInstance().then((prefs) => prefs.saveAppSettings(_settings));

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseDatabase.instance
          .ref("users/${user.uid}/settings")
          .update({"remindersEnabled": enabled});
    }
    notifyListeners();
  }

  void updateInterceptLinks(bool enabled) {
    _settings.interceptLinks = enabled;
    Preferences.getInstance().then((prefs) => prefs.saveAppSettings(_settings));

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseDatabase.instance
          .ref("users/${user.uid}/settings")
          .update({"interceptLinks": enabled});
    }

    // Call native code to enable/disable the intent filter
    const platform = MethodChannel('sk.panakrala.scenickazatva/settings');
    try {
      platform.invokeMethod('setInterceptLinks', {"enabled": enabled});
    } catch (e) {
      debugPrint("Error calling native setInterceptLinks: $e");
    }

    notifyListeners();
  }

  Map<String, dynamic> _deepConvertMap(dynamic map) {
    if (map == null) return {};
    if (map is! Map) return {};

    final Map<String, dynamic> result = {};

    map.forEach((key, value) {
      // Firebase keys are almost always Strings, but we cast safely
      final String StringKey = key.toString();

      if (value is Map) {
        result[StringKey] = _deepConvertMap(value);
      } else if (value is List) {
        result[StringKey] = value.map((i) => i is Map ? _deepConvertMap(i) : i).toList();
      } else {
        result[StringKey] = value;
      }
    });

    return result;
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }
}
