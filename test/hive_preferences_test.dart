import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:scenickazatva_app/models/HivePreferences.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/Ad.dart';

void main() {
  Hive
    ..registerAdapter(FestivalAdapter())
    ..registerAdapter(AppSettingsAdapter())
    ..registerAdapter(AdAdapter());

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_prefs_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('AppSettings round-trips through the box', () async {
    final prefs = await Preferences.getInstance();
    final settings = AppSettings()..defaultfestival = 'fest-x';
    await prefs.saveAppSettings(settings);
    expect(prefs.getAppSettings().defaultfestival, 'fest-x');
  });

  test('Festival round-trips through the box', () async {
    final prefs = await Preferences.getInstance();
    final festival = Festival()..id = 'fest-x';
    await prefs.saveFestival(festival);
    expect(prefs.getFestival().id, 'fest-x');
  });

  test('stored settings are ignored when the stored schema is newer', () async {
    final box = await Hive.openBox<Object>('_preferencesBox');
    await box.put('schema_version', Preferences.currentSchemaVersion + 1);
    await box.put('app_settings', AppSettings()..defaultfestival = 'future');

    final prefs = await Preferences.getInstance();
    expect(prefs.getAppSettings().defaultfestival, AppSettings().defaultfestival);
    expect(prefs.getFestival().id, Festival().id);
  });

  test('missing schema version is treated as compatible (legacy build)',
      () async {
    final box = await Hive.openBox<Object>('_preferencesBox');
    await box.put('app_settings', AppSettings()..defaultfestival = 'legacy');

    final prefs = await Preferences.getInstance();
    expect(prefs.getAppSettings().defaultfestival, 'legacy');
  });

  test('saving overrides the stored schema version to the current one',
      () async {
    final box = await Hive.openBox<Object>('_preferencesBox');
    await box.put('schema_version', Preferences.currentSchemaVersion + 1);
    await box.put('app_settings', AppSettings()..defaultfestival = 'future');

    final prefs = await Preferences.getInstance();
    await prefs.saveAppSettings(AppSettings()..defaultfestival = 'fresh');

    expect(prefs.getAppSettings().defaultfestival, 'fresh');
    expect(box.get('schema_version'), Preferences.currentSchemaVersion);
  });

  test('wrongly-typed stored value falls back to defaults instead of throwing',
      () async {
    final box = await Hive.openBox<Object>('_preferencesBox');
    await box.put('app_settings', 'not an AppSettings');
    final prefs = await Preferences.getInstance();
    expect(
        prefs.getAppSettings().defaultfestival, AppSettings().defaultfestival);
  });

  test('counter still round-trips as an int', () async {
    final prefs = await Preferences.getInstance();
    await prefs.setCounter(7);
    expect(prefs.getCounter(), 7);
  });
}
