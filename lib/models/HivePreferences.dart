import 'package:hive_ce/hive.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';

class Preferences {
  static const _preferencesBox = '_preferencesBox';

  // Keys - keeping these consistent is the most important part
  static const _settingsKey = 'app_settings';
  static const _festivalKey = 'current_festival';
  static const _counterKey = '_counterKey';

  // Schema versioning. Bump [currentSchemaVersion] when the shape of stored
  // AppSettings/Festival changes incompatibly; older builds then reset to
  // defaults instead of misreading future data.
  static const _schemaVersionKey = 'schema_version';
  static const int currentSchemaVersion = 1;

  final Box<Object> _box;

  Preferences._(this._box);

  static Future<Preferences> getInstance() async {
    // We open the box once here
    final box = await Hive.openBox<Object>(_preferencesBox);
    return Preferences._(box);
  }

  // --- App Settings ---

  // Renamed to match what your AppSettingsProvider calls
  Future<void> saveAppSettings(AppSettings settings) async {
    await _setValue(_settingsKey, settings);
    await _writeSchemaVersion();
  }

  AppSettings getAppSettings() {
    if (_storedSchemaIsNewer) return AppSettings();
    return _getValue(_settingsKey, defaultValue: AppSettings());
  }

  // --- Festival ---

  // Renamed to match what your FestivalProvider calls
  Future<void> saveFestival(Festival festival) async {
    await _setValue(_festivalKey, festival);
    await _writeSchemaVersion();
  }

  Festival getFestival() {
    if (_storedSchemaIsNewer) return Festival();
    return _getValue(_festivalKey, defaultValue: Festival());
  }

  // --- Helpers ---

  int getCounter() => _getValue(_counterKey, defaultValue: 0);
  Future<void> setCounter(int counter) => _setValue(_counterKey, counter);

  // Generic internal helpers to keep code dry
  T _getValue<T>(Object key, {required T defaultValue}) {
    final raw = _box.get(key);
    if (raw is! T) return defaultValue;
    return raw;
  }

  Future<void> _setValue<T>(Object key, Object value) =>
      _box.put(key, value);

  /// `true` when the stored box was written by a newer build whose schema we
  /// cannot safely interpret. A missing version key is treated as compatible
  /// (legacy builds predate versioning).
  bool get _storedSchemaIsNewer {
    final stored = _box.get(_schemaVersionKey);
    return stored is int && stored > currentSchemaVersion;
  }

  Future<void> _writeSchemaVersion() =>
      _box.put(_schemaVersionKey, currentSchemaVersion);
}