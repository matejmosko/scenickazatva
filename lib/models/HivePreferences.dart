import 'package:hive_ce/hive.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';

class Preferences {
  static const _preferencesBox = '_preferencesBox';

  // Keys - keeping these consistent is the most important part
  static const _settingsKey = 'app_settings';
  static const _festivalKey = 'current_festival';
  static const _counterKey = '_counterKey';

  final Box<Object> _box;

  Preferences._(this._box);

  static Future<Preferences> getInstance() async {
    // We open the box once here
    final box = await Hive.openBox<Object>(_preferencesBox);
    return Preferences._(box);
  }

  // --- App Settings ---

  // Renamed to match what your AppSettingsProvider calls
  Future<void> saveAppSettings(AppSettings settings) =>
      _setValue(_settingsKey, settings);

  AppSettings getAppSettings() =>
      _getValue(_settingsKey, defaultValue: AppSettings());

  // --- Festival ---

  // Renamed to match what your FestivalProvider calls
  Future<void> saveFestival(Festival festival) =>
      _setValue(_festivalKey, festival);

  Festival getFestival() =>
      _getValue(_festivalKey, defaultValue: Festival());

  // --- Helpers ---

  int getCounter() => _getValue(_counterKey, defaultValue: 0);
  Future<void> setCounter(int counter) => _setValue(_counterKey, counter);

  // Generic internal helpers to keep code dry
  T _getValue<T>(Object key, {required T defaultValue}) =>
      _box.get(key, defaultValue: defaultValue) as T;

  Future<void> _setValue<T>(Object key, Object value) =>
      _box.put(key, value);
}