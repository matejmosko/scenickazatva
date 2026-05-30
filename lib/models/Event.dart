import 'package:scenickazatva_app/utils/TimeUtils.dart';

class Event {
  String id = "";
  String title = "";
  String description = "";
  String location = "";
  String type = "";
  DateTime? startTime;
  DateTime? endTime;
  String image = "";
  String artist = "";

  Event({
    this.id = "",
    this.title = "",
    this.startTime,
    this.endTime,
    this.location = "",
    this.type = "",
    this.image = "",
    this.description = "",
    this.artist = "",
  });

  factory Event.fromJson(Map<String, dynamic> json){
    DateTime? parseDateTime(dynamic value) {
      if (value is! String) return null;
      try {
        final match = RegExp(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})').firstMatch(value);
        if (match == null) return null;
        
        String cleanValue = match.group(1)!;
        DateTime naive = DateTime.parse(cleanValue);

        return TimeUtils.toUtc(naive);
      } catch (e) {
        return null;
      }
    }

    var startTime = parseDateTime(json['startTime']);
    var endTime = parseDateTime(json['endTime']);

    return Event(
      id: json['id'] ?? "",
      title: json['title'] ?? "",
      description: json['description'] ?? "",
      location: json['location'] ?? "",
      type: json['type'] ?? "",
      startTime: startTime ?? DateTime.now(),
      endTime: endTime ?? DateTime.now(),
      image: json['image'] ?? "",
      artist: json['artist'] ?? "",
    );
  }

  Event copy() {
    return Event(
      id: id,
      title: title,
      description: description,
      location: location,
      type: type,
      startTime: startTime,
      endTime: endTime,
      image: image,
      artist: artist,
    );
  }

  Map<String, dynamic> toJson() {
    String? formatDateTime(DateTime? dt) {
      if (dt == null) return null;
      
      final festivalTime = TimeUtils.fromUtc(dt);
      
      // Produce a string like "2025-08-27T19:00:00.000" (no 'Z' or offset)
      return festivalTime.toIso8601String().split(RegExp(r'Z|[+-]'))[0];
    }

    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'type': type,
      'startTime': formatDateTime(startTime),
      'endTime': formatDateTime(endTime),
      'image': image,
      'artist': artist
    };
  }
}
