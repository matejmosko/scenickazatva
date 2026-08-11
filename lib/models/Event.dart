import 'package:scenickazatva_app/utils/TimeUtils.dart';
import 'package:timezone/timezone.dart' as tz;

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
        // Values with an explicit UTC marker ('Z') or numeric offset are
        // absolute instants, e.g. "2026-06-16T17:25:00.000Z".
        final hasZone = value.contains('T') &&
            RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(value);
        if (hasZone) {
          return DateTime.parse(value).toUtc();
        }
        // Legacy naive values (no zone info) are Europe/Prague wall-clock times.
        return TimeUtils.toUtc(DateTime.parse(value));
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

      // Store as Europe/Prague wall-clock time with the explicit offset, e.g.
      // "2026-06-16T19:25:00.000+0200" in summer / "2026-01-16T19:25:00.000+0100"
      // in winter. The offset is derived from the actual date, so the stored
      // value is unambiguous and human-readable for the festival's zone.
      final local = TimeUtils.fromUtc(dt);
      final clean = tz.TZDateTime(
        local.location,
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
      );
      return clean.toIso8601String();
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
