import 'package:timezone/timezone.dart' as tz;
import 'package:scenickazatva_app/utils/AppLog.dart';

class TimeUtils {
  static tz.Location get festivalLocation {
    try {
      return tz.getLocation('Europe/Prague');
    } catch (e) {
      AppLog.warn("TimeUtils: Europe/Prague not found, falling back to UTC. Error: $e");
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
