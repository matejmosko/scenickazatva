import 'package:hive_ce/hive.dart';
part 'Festival.g.dart';

@HiveType(typeId: 1)
class Festival {
  @HiveField(0)
  DateTime? endDate = DateTime.utc(2030-12-31);
  @HiveField(1)
  String magazine_src =
      "https://javisko.sk/wp-json/wp/v2/posts?per_page=20&order=desc&";
  @HiveField(2)
  String news_src =
      "https://www.tvor-ba.sk/2024/wp-json/wp/v2/posts?per_page=20&order=desc&";
  @HiveField(3)
  DateTime? startDate = DateTime.utc(2022-01-01);
  @HiveField(4)
  String subtitle = "Národné osvetové centrum";
  @HiveField(5)
  String title = "Festivaly NOC";
  @HiveField(6)
  String backgroundColor;
  @HiveField(7)
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

  Festival(
      {this.endDate,
      this.magazine_src =
          "https://javisko.sk/wp-json/wp/v2/posts?per_page=20&order=desc&",
      this.news_src =
          "https://www.tvor-ba.sk/2024/wp-json/wp/v2/posts?per_page=20&order=desc&",
      this.startDate,
      this.subtitle = "Národné osvetové centrum",
      this.title = "Festivaly NOC",
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
      this.background = "gs://scenickazatva-343517.appspot.com/default.png"});

  factory Festival.fromJson(Map<String, dynamic> json) {
    //Map<String, dynamic> festivals = jsonDecode(json['festivals'] ?? {});

    var startDate = DateTime.parse(json['startdate']);
    var endDate = DateTime.parse(json['enddate']);

    return Festival(
        endDate: endDate,
        magazine_src: json['magazine_src'],
        news_src: json['news_src'],
        startDate: startDate,
        subtitle: json['subtitle'],
        title: json['title'],
        backgroundColor: json['backgroundColor'],
        foregroundColor: json['foregroundColor'],
        festivalBackgroundColor: json['festivalBackgroundColor'],
        festivalForegroundColor: json['festivalForegroundColor'],
        festivalThirdColor: json['festivalThirdColor'],
        selectedColor: json['selectedColor'],
        mainProgramColor: json['mainProgramColor'],
        partnerProgramColor: json['partnerProgramColor'],
        offProgramColor: json['offProgramColor'],
        logo: json['logo'],
        background: json['background']
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['enddate'] = this.endDate;
    data['magazine_src'] = this.magazine_src;
    data['news_src'] = this.magazine_src;
    data['startdate'] = this.startDate;
    data['subtitle'] = this.subtitle;
    data['title'] = this.title;
    data['backgroundColor'] = this.backgroundColor;
    data['foregroundColor'] = this.foregroundColor;
    data['festivalBackgroundColor'] = this.festivalBackgroundColor;
    data['festivalForegroundColor'] = this.festivalForegroundColor;
    data['festivalThirdColor'] = this.festivalThirdColor;
    data['selectedColor'] = this.selectedColor;
    data['mainProgramColor'] = this.mainProgramColor;
    data['offProgramColor'] = this.offProgramColor;
    data['partnerProgramColor'] = this.partnerProgramColor;
    data['logo'] = this.logo;
    data['background'] = this.background;
    return data;
  }
}
