import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
//import 'package:timezone/data/latest.dart' as tz;
import 'package:scenickazatva_app/models/Event.dart';
import 'package:flutter/foundation.dart';
import 'package:scenickazatva_app/utils/TimeUtils.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Callback for handling notification taps
  Function(String)? onNotificationTap;

  Future<void> init() async {
    // tz.initializeTimeZones(); // Already initialized in main()
    
    // Set default timezone to Prague (same offset as Bratislava) as a fallback for Slovak festivals
    try {
      tz.setLocalLocation(TimeUtils.festivalLocation);
    } catch (e) {
      debugPrint("NotificationService: Could not set default timezone: $e");
    }
    
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
        if (details.payload != null && details.payload!.startsWith('/events/')) {
          onNotificationTap?.call(details.payload!);
        }
      },
    );

    // Check if the app was launched via a notification
    final NotificationAppLaunchDetails? launchDetails = 
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payload = launchDetails.notificationResponse?.payload;
      if (payload != null && payload.startsWith('/events/')) {
        // Delay slightly to ensure the router/app is ready to handle navigation
        Future.delayed(const Duration(seconds: 1), () {
          onNotificationTap?.call(payload);
        });
      }
    }

    // Request permissions for Android 13+
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleEventNotification(Event event) async {
    if (event.startTime == null) return;

    final location = TimeUtils.festivalLocation;
    
    // Convert the UTC startTime from the model to the festival's local time
    final festivalStart = TimeUtils.fromUtc(event.startTime!);

    // Calculate the notification time (30 minutes before)
    final scheduledDate = festivalStart.subtract(const Duration(minutes: 30));
    final tzNow = tz.TZDateTime.now(location);

    // Don't schedule if the time has already passed
    if (scheduledDate.isBefore(tzNow)) {
      debugPrint("NotificationService: Skipping schedule for ${event.title}, wall-clock time ($scheduledDate) already passed (now: $tzNow).");
      return;
    }

    // Use a unique ID based on the event's hash code (mask to 31-bit for Android safety)
    final id = event.id.hashCode & 0x7FFFFFFF;

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: 'Pripomienka programu',
        body: 'Tvoj obľúbený program "${event.title}" začína o 30 minút.',
        scheduledDate: scheduledDate,
        payload: '/events/${event.id}',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'favorites_channel',
            'Obľúbené programy',
            channelDescription: 'Upozornenia na začiatok obľúbených podujatí',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint("NotificationService: Scheduled notification $id for ${event.title} at $scheduledDate (Instant: ${scheduledDate.toUtc()})");
    } catch (e) {
      debugPrint("NotificationService: Error scheduling notification for ${event.title}: $e");
    }
  }

  Future<void> cancelEventNotification(Event event) async {
    final id = event.id.hashCode & 0x7FFFFFFF;
    await _notificationsPlugin.cancel(id: id);
    debugPrint("NotificationService: Cancelled notification $id for ${event.title}");
  }
}
