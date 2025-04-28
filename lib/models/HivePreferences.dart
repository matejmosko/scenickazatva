import 'package:hive_ce/hive.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';

// Based on this manual https://medium.com/flutter-community/using-hive-instead-of-sharedpreferences-for-storing-preferences-2d98c9db930f

class Preferences {
  static const _preferencesBox = '_preferencesBox';
  static const _counterKey = '_counterKey';
  static const _settingsKey = '_appSettings';
  static const _festivalKey = '_festival';
  final Box<Object> _box;

  Preferences._(this._box);

  // This doesn't have to be a singleton.
  // We just want to make sure that the box is open, before we start getting/setting objects on it
  static Future<Preferences> getInstance() async {

    final box = await Hive.openBox<Object>(_preferencesBox);
    return Preferences._(box);
  }

  int getCounter() => _getValue(_counterKey, defaultValue: 0);
  Future<void> setCounter(int counter) => _setValue(_counterKey, counter);

  AppSettings getPrefs() => _getValue(_settingsKey, defaultValue: AppSettings());
  Future<void> setPrefs(AppSettings settings) => _setValue(_settingsKey, settings);

  Festival getFestival() => _getValue(_festivalKey, defaultValue: Festival());
  Future<void> setFestival(Festival festival) => _setValue(_festivalKey, festival);

  T _getValue<T>(Object key, {required T defaultValue}) => _box.get(key, defaultValue: defaultValue) as T;

  Future<void> _setValue<T>(Object key, Object value) => _box.put(key, value);
}