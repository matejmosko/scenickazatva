import 'package:hive_ce/hive.dart';

part 'Ad.g.dart';

@HiveType(typeId: 4)
class Ad {
  @HiveField(0)
  String title = "";
  
  @HiveField(1)
  String description = "";
  
  @HiveField(2)
  String image = "";
  
  @HiveField(3)
  String link = "";
  
  @HiveField(4)
  String cta = "";
  
  @HiveField(5)
  bool show = false;

  Ad({
    this.title = "",
    this.description = "",
    this.image = "",
    this.link = "",
    this.cta = "",
    this.show = false,
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    // Handle both bool and int for 'show'
    bool showVal = false;
    if (json['show'] is bool) {
      showVal = json['show'];
    } else if (json['show'] is num) {
      showVal = json['show'] == 1;
    }

    return Ad(
      title: json['title'] ?? "",
      description: json['description'] ?? "",
      image: json['image'] ?? "",
      link: json['link'] ?? "",
      cta: json['cta'] ?? "",
      show: showVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'image': image,
      'link': link,
      'cta': cta,
      'show': show,
    };
  }
}
