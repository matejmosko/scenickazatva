import 'dart:async';
import 'package:flutter/material.dart'; // Change dart:ui to material for more features
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/HivePreferences.dart';
import 'package:scenickazatva_app/requests/ImagePrecacheService.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';

class FestivalProvider extends ChangeNotifier {
  Festival _festival = Festival();
  bool loading = false; // Set to false by default now

  FestivalProvider() {
    _loadFromHive();
  }

  Festival get festival => _festival;

  // Accessors with Null-Safety/Fallback logic
  Color get backgroundColor => _getColor(_festival.backgroundColor, Colors.white);
  Color get foregroundColor => _getColor(_festival.foregroundColor, Colors.black);
  Color get festivalBackgroundColor => _getColor(_festival.festivalBackgroundColor, Colors.white);
  Color get festivalForegroundColor => _getColor(_festival.festivalForegroundColor, Colors.black);
  Color get festivalThirdColor => _getColor(_festival.festivalThirdColor, Colors.grey);
  Color get selectedColor => _getColor(_festival.selectedColor, Colors.blue);
  Color get mainProgramColor => _getColor(_festival.mainProgramColor, Colors.red);
  Color get offProgramColor => _getColor(_festival.offProgramColor, Colors.orange);
  Color get partnerProgramColor => _getColor(_festival.partnerProgramColor, Colors.green);

  // This is the only method needed to keep data in sync
  void updateFromSettings(AppSettings settings) {
    String activeId = settings.defaultfestival;

    if (settings.festivals.containsKey(activeId)) {
      _festival = settings.festivals[activeId]!;
      loading = false;
      
      // Precache festival logo
      ImagePrecacheService().precacheFirebaseImage(_festival.logo);
      
      notifyListeners();
    }
  }

  Future<void> _loadFromHive() async {
    try {
      Preferences prefs = await Preferences.getInstance();
      _festival = prefs.getFestival();
      
      // Precache festival logo
      ImagePrecacheService().precacheFirebaseImage(_festival.logo);

      notifyListeners();
    } catch (e) {
      AppLog.error("Error loading festival from Hive", error: e);
    }
  }

  // Helper method for color parsing
  Color _getColor(String? colorString, Color fallback) {
    if (colorString == null || colorString.isEmpty) return fallback;
    try {
      String cleanHex = colorString.replaceAll('#', '');
      if (cleanHex.length == 6) cleanHex = "FF$cleanHex";
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      return fallback;
    }
  }
}