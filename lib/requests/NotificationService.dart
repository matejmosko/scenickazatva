import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:scenickazatva_app/models/Event.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap if needed
      },
    );
  }

  Future<void> scheduleEventNotification(Event event) async {
    if (event.startTime == null) return;

    // Calculate the notification time (30 minutes before)
    final notificationTime = event.startTime!.subtract(const Duration(minutes: 30));

    // Don't schedule if the time has already passed
    if (notificationTime.isBefore(DateTime.now())) {
      debugPrint("NotificationService: Skipping schedule for ${event.title}, time already passed.");
      return;
    }

    // Use a unique ID based on the event's hash code or ID
    final id = event.id.hashCode;

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: 'Pripomienka programu',
      body: 'Tvoj obľúbený program "${event.title}" začína o 30 minút.',
      scheduledDate: tz.TZDateTime.from(notificationTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'favorites_channel',
          'Obľúbené programy',
          channelDescription: 'Upozornenia na začiatok obľúbených podujatí',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    
    debugPrint("NotificationService: Scheduled notification for ${event.title} at $notificationTime");
  }

  Future<void> cancelEventNotification(Event event) async {
    final id = event.id.hashCode;
    await _notificationsPlugin.cancel(id: id);
    debugPrint("NotificationService: Cancelled notification for ${event.title}");
  }
}
