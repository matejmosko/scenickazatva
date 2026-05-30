import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class TimeUtils {
  static tz.Location get festivalLocation {
    try {
      return tz.getLocation('Europe/Prague');
    } catch (e) {
      debugPrint("TimeUtils: Europe/Prague not found, falling back to UTC. Error: $e");
      return tz.UTC;
    }
  }

  static DateTime toUtc(DateTime naive) {
    final location = festivalLocation;
    final festivalTime = tz.TZDateTime(
      location,
      naive.year,
      naive.month,
      naive.day,
      naive.hour,
      naive.minute,
      naive.second,
    );
    return festivalTime.toUtc();
  }

  static tz.TZDateTime fromUtc(DateTime utc) {
    return tz.TZDateTime.from(utc, festivalLocation);
  }
}
