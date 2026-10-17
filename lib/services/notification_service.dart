// lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init(String religion) async {
    if (kIsWeb) return;

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notificationsPlugin.initialize(initializationSettings);

      // Load saved notification preference or default to 7:00 AM
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notif_enabled') ?? true;
      if (enabled) {
        final hour = prefs.getInt('notif_hour') ?? 7;
        final minute = prefs.getInt('notif_minute') ?? 0;
        await scheduleDailyNotification(hour, minute, religion);
      }
    } catch (e) {
      debugPrint('Notification Init Error: $e');
    }
  }

  /// ⏰ User-selected Custom Time par notification schedule karo
  static Future<void> scheduleDailyNotification(
      int hour, int minute, String religion) async {
    if (kIsWeb) return;

    try {
      // Save preferences locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notif_hour', hour);
      await prefs.setInt('notif_minute', minute);
      await prefs.setBool('notif_enabled', true);

      // Clear previous notifications before setting new time
      await _notificationsPlugin.cancelAll();

      String title = '🕉️ Aaj Ka Gita Shlok';
      String body =
          'Aaj ka shlok padhein aur apne din mein shanti aur prerna paayein. 🙏';

      if (religion == 'islamic') {
        title = '☪️ Daily Quran Verse';
        body = 'Aaj ki Quran Ayat padhein aur apne din ko roshan karein. 🤲';
      } else if (religion == 'sikh') {
        title = '☬ Daily Gurbani Shabad';
        body = 'Aaj ka Gurbani Shabad padhein aur Waheguru ka simran karein. ੴ';
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'daily_verse_channel',
        'Daily Verse Reminders',
        channelDescription: 'Custom daily verse notification',
        importance: Importance.max,
        priority: Priority.high,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      // Agar aaj ka time nikal chuka hai, toh kal ke liye schedule karo
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        0,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Har din repeat!
      );

      debugPrint('Notification scheduled for $hour:$minute daily');
    } catch (e) {
      debugPrint('Schedule Notification Error: $e');
    }
  }

  /// 🔕 Notification Toggle On/Off
  static Future<void> toggleNotification(bool enable, String religion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', enable);

    if (!enable) {
      await _notificationsPlugin.cancelAll();
    } else {
      final hour = prefs.getInt('notif_hour') ?? 7;
      final minute = prefs.getInt('notif_minute') ?? 0;
      await scheduleDailyNotification(hour, minute, religion);
    }
  }
}
