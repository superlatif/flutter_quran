import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service untuk notifikasi lokal & alarm pembacaan harian.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int reminderId = 1001;
  static const String reminderTitle = 'Pengingat Membaca Al-Qur\'an';
  static const String reminderBody =
      'Yuk sempatkan membaca Al-Qur\'an hari ini!';

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await FlutterLocalNotificationsPlugin().initialize(
      settings: settings,
      onDidReceiveNotificationResponse: null,
      onDidReceiveBackgroundNotificationResponse: null,
    );

    await AndroidAlarmManager.initialize();
  }

  Future<void> scheduleHourlyReminder() async {
    await FlutterLocalNotificationsPlugin().periodicallyShow(
      id: reminderId,
      repeatInterval: RepeatInterval.hourly,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'alquran_reminders',
          'Alquran Reminders',
          channelDescription: 'Pengingat membaca Al-Qur\'an',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: reminderTitle,
      body: reminderBody,
    );
  }

  Future<void> cancelHourlyReminder() async {
    await FlutterLocalNotificationsPlugin().cancel(id: reminderId);
  }

  Future<void> stopAndRescheduleIfNeeded() async {
    await cancelHourlyReminder();
    await scheduleHourlyReminder();
  }
}
