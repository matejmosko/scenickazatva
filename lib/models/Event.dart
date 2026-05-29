
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
        DateTime dt = DateTime.parse(value);
        // We always want to treat the time from the database as the "wall-clock" time.
        // If it's UTC, we convert it to local with the same hour/minute to avoid shifts.
        if (dt.isUtc) {
          return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
        }
        return dt;
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
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'type': type,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'image': image,
      'artist': artist
    };
  }
}
