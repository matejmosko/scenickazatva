import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/Ad.dart';
import 'package:hive_ce/hive.dart';
part 'AppSettings.g.dart';

@HiveType(typeId : 0)
class AppSettings {
  @HiveField(0)
  String defaultfestival = "sutaze";

  @HiveField(1)
  Map<String, Festival> festivals = {}; // Removed nullability for easier access

  @HiveField(2)
  double fontSizeFactor = 1.0;

  @HiveField(3)
  bool notificationsEnabled = true;

  @HiveField(4)
  bool remindersEnabled = true;

  @HiveField(5)
  int lastMagazinePostId = 0;

  @HiveField(6)
  bool interceptLinks = true;

  @HiveField(7)
  List<Ad> ads = [];

  @HiveField(8)
  int themeModeIndex = 0; // 0: System, 1: Light, 2: Dark

  @HiveField(9)
  String magazineSrc = "";

  AppSettings({
    this.defaultfestival = "sutaze",
    this.festivals = const {},
    this.fontSizeFactor = 1.0,
    this.notificationsEnabled = true,
    this.remindersEnabled = true,
    this.lastMagazinePostId = 0,
    this.interceptLinks = true,
    this.ads = const [],
    this.themeModeIndex = 0,
    this.magazineSrc = "",
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

    // Handle ads
    List<Ad> adsList = [];
    if (json['ads'] is List) {
      adsList = (json['ads'] as List)
          .map((item) => Ad.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    return AppSettings(
      // 3. Fix the null check at caret
      defaultfestival: json['defaultfestival']?.toString() ?? "sutaze",
      festivals: festivalsMap,
      fontSizeFactor: (json['fontSizeFactor'] ?? 1.0).toDouble(),
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      remindersEnabled: json['remindersEnabled'] ?? true,
      lastMagazinePostId: json['lastMagazinePostId'] ?? 0,
      interceptLinks: json['interceptLinks'] ?? true,
      ads: adsList,
      themeModeIndex: json['themeModeIndex'] ?? 0,
      magazineSrc: json['magazine_src'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultfestival': defaultfestival,
      'festivals': festivals.map((key, value) => MapEntry(key, value.toJson())),
      'fontSizeFactor': fontSizeFactor,
      'notificationsEnabled': notificationsEnabled,
      'remindersEnabled': remindersEnabled,
      'lastMagazinePostId': lastMagazinePostId,
      'interceptLinks': interceptLinks,
      'ads': ads.map((ad) => ad.toJson()).toList(),
      'themeModeIndex': themeModeIndex,
      'magazine_src': magazineSrc,
    };
  }
}
