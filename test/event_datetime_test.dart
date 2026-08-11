import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:scenickazatva_app/models/Event.dart';

void main() {
  tzdata.initializeTimeZones();
  final prague = tz.getLocation('Europe/Prague');

  test('parses legacy naive Prague values as Europe/Prague wall-clock', () {
    final event = Event.fromJson({
      'startTime': '2026-06-16T19:25:00.000',
      'endTime': '2026-06-16T21:25:00.000',
    });
    expect(event.startTime!.toUtc().toIso8601String(), '2026-06-16T17:25:00.000Z');
  });

  test('parses Z values as UTC', () {
    final event = Event.fromJson({
      'startTime': '2026-06-16T17:25:00.000Z',
      'endTime': '2026-06-16T19:25:00.000Z',
    });
    expect(event.startTime!.toUtc().toIso8601String(), '2026-06-16T17:25:00.000Z');
  });

  test('parses offset values as absolute instants (with and without colon)', () {
    final event = Event.fromJson({
      'startTime': '2026-06-16T19:25:00.000+02:00',
      'endTime': '2026-06-16T19:25:00.000+0200',
    });
    expect(event.startTime!.toUtc().toIso8601String(), '2026-06-16T17:25:00.000Z');
    expect(event.endTime!.toUtc().toIso8601String(), '2026-06-16T17:25:00.000Z');
  });

  test('round-trips legacy values to Prague local with offset', () {
    final event = Event.fromJson({'startTime': '2026-06-16T19:25:00.000'});
    expect(event.toJson()['startTime'], '2026-06-16T19:25:00.000+0200');
  });

  test('serializes Prague TZDateTime with summer offset (edit page path)', () {
    final event = Event(startTime: tz.TZDateTime(prague, 2026, 6, 16, 19, 25));
    expect(event.toJson()['startTime'], '2026-06-16T19:25:00.000+0200');
  });

  test('serializes with winter offset', () {
    final event = Event(startTime: tz.TZDateTime(prague, 2026, 1, 16, 19, 25));
    expect(event.toJson()['startTime'], '2026-01-16T19:25:00.000+0100');
  });

  test('stored offset values parse back to the same instant', () {
    final event = Event.fromJson({'startTime': '2026-06-16T19:25:00.000+0200'});
    expect(event.toJson()['startTime'], '2026-06-16T19:25:00.000+0200');
  });
}
