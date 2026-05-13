import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scenickazatva_app/requests/api.dart';
import 'package:scenickazatva_app/models/HivePreferences.dart';

class AppSettingsRequest{
  AppSettings _appsettings = AppSettings();
  bool loading = false;
  String defaultfestival = "";

  AppSettingsRequest() {
    fetchSettings();
  }

  AppSettings get appsettings => _appsettings;

  void fetchSettings() async {
    defaultfestival = await API().getDefaultFestival();
    FirebaseDatabase database = FirebaseDatabase.instance;
    if(!kIsWeb){database.setPersistenceEnabled(true);}



    final settingsdb = FirebaseDatabase.instance.ref("appsettings/");
    //if(!kIsWeb){settingsdb.keepSynced(true);}
    // Get the Stream
    Stream<DatabaseEvent> stream = settingsdb.onValue;

// Subscribe to the stream!
    stream.listen((DatabaseEvent settingsdb) {
      Map<String,dynamic> list = json.decode(json.encode(settingsdb.snapshot.value)) as Map<String,dynamic>;
      //Map<String,dynamic> validMap = json.decode(json.encode(settingsdb.snapshot.value));
      setSettings(
          //list.map((model) => AppSettings.fromJson(model))
           AppSettings.fromJson(list)
      );
    });
  }

  void setSettings(AppSettings list) async {
    defaultfestival = await API().getDefaultFestival();
    _appsettings = list;
    Preferences prefs = await Preferences.getInstance();
    prefs.setPrefs(_appsettings);
   // prefs.setFestival(_appsettings.festivals![_appsettings.defaultfestival]!);
    prefs.setFestival(_appsettings.festivals![defaultfestival]!);
    }
}
