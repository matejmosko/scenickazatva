import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/HivePreferences.dart';

class FestivalProvider extends ChangeNotifier {
  Festival _festival = Festival();
  bool loading = false;

  FestivalProvider() {
    fetchFestival();
  }

  Festival get festival => _festival;

  Color get backgroundColor => getColor(_festival.backgroundColor);
  Color get foregroundColor => getColor(_festival.foregroundColor);
  Color get festivalBackgroundColor => getColor(_festival.festivalBackgroundColor);
  Color get festivalForegroundColor => getColor(_festival.festivalForegroundColor);
  Color get festivalThirdColor => getColor(_festival.festivalThirdColor);
  Color get selectedColor => getColor(_festival.selectedColor);
  Color get mainProgramColor => getColor(_festival.mainProgramColor);
  Color get offProgramColor => getColor(_festival.offProgramColor);
  Color get partnerProgramColor => getColor(_festival.partnerProgramColor);

  Future<Festival> fetchFestival() async {
    Preferences prefs = await Preferences.getInstance();
    Festival festival = prefs.getFestival();

    setFestival(festival);
    return festival;
  }

  void setLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  void setFestival(Festival fest) {
    _festival = fest;
    notifyListeners();
    setLoading(false);
  }

  Color getColor(String colorString) {
    int colorInt = int.parse(colorString, radix: 16);
    Color color = new Color(colorInt);
    return color;
  }
}
