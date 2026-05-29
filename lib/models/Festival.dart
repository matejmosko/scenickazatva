import 'package:hive_ce/hive.dart';part 'Festival.g.dart';

@HiveType(typeId: 1)
class Festival {
  @HiveField(0)
  DateTime? endDate;

  @HiveField(1)
  String magazine_src;

  @HiveField(2)
  String news_src;

  @HiveField(3)
  DateTime? startDate;

  @HiveField(4)
  String subtitle;

  @HiveField(5)
  String title;

  @HiveField(6)
  String backgroundColor;

  @HiveField(7) // FIXED: Removed the word 'title' stuck to the annotation
  String foregroundColor;

  @HiveField(8)
  String selectedColor;

  @HiveField(9)
  String mainProgramColor;

  @HiveField(10)
  String offProgramColor;

  @HiveField(11)
  String logo;

  @HiveField(12)
  String background;

  @HiveField(13)
  String partnerProgramColor;

  @HiveField(14)
  String festivalBackgroundColor;

  @HiveField(15)
  String festivalForegroundColor;

  @HiveField(16)
  String festivalThirdColor;

  @HiveField(17)
  String menuTitle;

  @HiveField(18)
  String id;

  @HiveField(19)
  int lastNewsPostId;

  Festival({
    this.endDate,
    this.startDate,
    this.magazine_src = "https://javisko.sk/wp-json/wp/v2/posts?per_page=20&order=desc&",
    this.news_src = "https://www.scenickazatva.eu/2025/wp-json/wp/v2/posts?per_page=20&order=desc&",
    this.subtitle = "Národné osvetové centrum",
    this.title = "Festivaly NOC",
    this.menuTitle = "Festivaly",
    this.backgroundColor = "ffffffff",
    this.foregroundColor = "ff000000",
    this.festivalBackgroundColor = "ffffffff",
    this.festivalForegroundColor = "ff000000",
    this.festivalThirdColor = "ff000000",
    this.selectedColor = "ff888888",
    this.mainProgramColor = "ffffffff",
    this.offProgramColor = "ffffffff",
    this.partnerProgramColor = "ffffffff",
    this.logo = "gs://scenickazatva-343517.appspot.com/default.png",
    this.background = "gs://scenickazatva-343517.appspot.com/default.png",
    this.id = "default",
    this.lastNewsPostId = 0,
  });

  factory Festival.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        DateTime? dt = DateTime.tryParse(value.toString());
        if (dt == null) return null;
        if (dt.isUtc) {
          return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
        }
        return dt;
      } catch (e) {
        return null;
      }
    }

    // Safety parsing for dates to prevent crashes on bad data
    DateTime? parsedStart = parseDateTime(json['startdate']);
    DateTime? parsedEnd = parseDateTime(json['enddate']);

    return Festival(
      endDate: parsedEnd,
      startDate: parsedStart,
      magazine_src: json['magazine_src'] ?? "",
      news_src: json['news_src'] ?? "",
      subtitle: json['subtitle'] ?? "",
      title: json['title'] ?? "",
      menuTitle: json['menuTitle'] ?? "",
      backgroundColor: json['backgroundColor'] ?? "ffffffff",
      foregroundColor: json['foregroundColor'] ?? "ff000000",
      festivalBackgroundColor: json['festivalBackgroundColor'] ?? "ffffffff",
      festivalForegroundColor: json['festivalForegroundColor'] ?? "ff000000",
      festivalThirdColor: json['festivalThirdColor'] ?? "ff000000",
      selectedColor: json['selectedColor'] ?? "ff888888",
      mainProgramColor: json['mainProgramColor'] ?? "ffffffff",
      partnerProgramColor: json['partnerProgramColor'] ?? "ffffffff",
      offProgramColor: json['offProgramColor'] ?? "ffffffff",
      logo: json['logo'] ?? "gs://scenickazatva-343517.appspot.com/default.png",
      background: json['background'] ?? "gs://scenickazatva-343517.appspot.com/default.png",
      id: id ?? json['id'] ?? "default",
      lastNewsPostId: json['lastNewsPostId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enddate': endDate?.toIso8601String(),
      'startdate': startDate?.toIso8601String(),
      'magazine_src': magazine_src,
      'news_src': news_src, // FIXED: was magazine_src previously
      'subtitle': subtitle,
      'title': title,
      'menuTitle': menuTitle,
      'backgroundColor': backgroundColor,
      'foregroundColor': foregroundColor,
      'festivalBackgroundColor': festivalBackgroundColor,
      'festivalForegroundColor': festivalForegroundColor,
      'festivalThirdColor': festivalThirdColor,
      'selectedColor': selectedColor,
      'mainProgramColor': mainProgramColor,
      'offProgramColor': offProgramColor,
      'partnerProgramColor': partnerProgramColor,
      'logo': logo,
      'background': background,
      'id': id,
      'lastNewsPostId': lastNewsPostId,
    };
  }
}