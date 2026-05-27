import 'package:scenickazatva_app/models/Festival.dart';
import 'package:hive_ce/hive.dart';
part 'AppSettings.g.dart';

@HiveType(typeId : 0)
class AppSettings {
  @HiveField(0)
  String defaultfestival = "sutaze";

  @HiveField(1)
  Map<String, Festival> festivals = {}; // Removed nullability for easier access

  AppSettings({
    this.defaultfestival = "sutaze",
    this.festivals = const {},
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // 1. Safely handle the festivals map
    final dynamic rawFestivals = json["festivals"];
    Map<String, Festival> festivalsMap = {};

    if (rawFestivals is Map) {
      rawFestivals.forEach((key, value) {
        if (value is Map) {
          // 2. CRITICAL: Pass the 'key' (id) into the Festival factory
          // so the Festival object knows it is "zp2026", "bm2025", etc.
          festivalsMap[key.toString()] = Festival.fromJson(
              Map<String, dynamic>.from(value),
              id: key.toString()
          );
        }
      });
    }

    return AppSettings(
      // 3. Fix the null check at caret
      defaultfestival: json['defaultfestival']?.toString() ?? "sutaze",
      festivals: festivalsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultfestival': defaultfestival,
      'festivals': festivals.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}