import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialization method called in main.dart
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    
    // Android Initialization
    await AndroidAlarmManager.initialize();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  // This is the background isolate function that runs when the alarm fires
  @pragma('vm:entry-point')
  static Future<void> alarmCallback(int id) async {
    // ignore: avoid_print
    print("🔥 Alarm triggered background isolate execution! ID: $id");
    
    // Ensure Flutter is initialized in this background isolate before using MethodChannels
    WidgetsFlutterBinding.ensureInitialized();

    // Re-initialize the plugin for the background isolate so it doesn't crash
    await initialize();
    await showInstantNotification(id);
  }

  // Trigger the actual alert banner/sound
  static Future<void> showInstantNotification(int id) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'execu_alarm_channel_id_v3', // Re-create channel to force new audio settings
      'Execu Alarms',
      channelDescription: 'Channel for Execu application task and habit alarms',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm, // Force use of Android's Alarm Volume stream
      icon: '@mipmap/ic_launcher',
      sound: const RawResourceAndroidNotificationSound('alarm'),
      // FLAG_INSISTENT (4) tells Android to loop the notification sound continuously until dismissed
      additionalFlags: Int32List.fromList(<int>[4]),
    );

    final NotificationDetails generalDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentSound: true, presentAlert: true),
    );

    await _notificationsPlugin.show(
      id,
      '⏰ Execu Reminder!',
      'It is time to complete your scheduled focus session or habit!',
      generalDetails,
    );
  }

  // Public method to schedule an alarm at a specific date/time
  static Future<void> setAlarm(int id, DateTime targetTime) async {
    if (targetTime.isBefore(DateTime.now())) return;

    await AndroidAlarmManager.oneShotAt(
      targetTime,
      id,
      alarmCallback,
      alarmClock: true, // Forces system status bar icon to show active alarm clock
      allowWhileIdle: true, // Wakes up phone from deep battery sleep (Doze mode)
      exact: true,
    );
  }

  // Cancel an alarm if user deletes or switches off a task/habit reminder
  static Future<void> cancelAlarm(int id) async {
    await AndroidAlarmManager.cancel(id);
    await _notificationsPlugin.cancel(id);
  }
}