import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:io'; // ✅ Added for strict target path safety checking
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:hive_flutter/hive_flutter.dart';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Stream to listen to notification banner taps in your UI
  static final StreamController<String?> notificationTapStream =
      StreamController<String?>.broadcast();

  // Background callback for notification actions (e.g. Dismiss button)
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse notificationResponse) async {
    // The notification cancels itself because cancelNotification is true.
    if (notificationResponse.actionId == 'snooze_alarm') {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      final int? id = notificationResponse.id;
      if (id != null) {
        String? customPath;
        if (notificationResponse.payload != null && notificationResponse.payload!.contains('|')) {
          customPath = notificationResponse.payload!.split('|').last;
          if (customPath.isEmpty) customPath = null;
        }
        final targetTime = DateTime.now().add(const Duration(minutes: 10));
        await setAlarm(id, targetTime, customTonePath: customPath);
      }
    }
  }

  // Initialization method called in main.dart
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    
    // Dynamically align tz.local to the device's current timezone offset.
    final now = DateTime.now();
    final offsetMilliseconds = now.timeZoneOffset.inMilliseconds;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.currentTimeZone.offset == offsetMilliseconds) {
        tz.setLocalLocation(location);
        break;
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        notificationTapStream.add(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  // Trigger the actual alert banner/sound
  static Future<void> showInstantNotification(int id, {String? audioPath}) async {
    String channelId = 'execu_alarm_channel_id_v6';
    AndroidNotificationSound sound = const RawResourceAndroidNotificationSound('alarm');

    // ✅ Absolute target location verification check logic
    bool useCustomAudio = false;
    if (audioPath != null && audioPath.isNotEmpty) {
      if (await File(audioPath).exists()) {
        useCustomAudio = true;
      }
    }

    if (useCustomAudio) {
      channelId = 'execu_alarm_channel_${audioPath.hashCode}';
      // ✅ FIX: Pass raw path string without adding structural prefix breaks parsing schemes
      sound = UriAndroidNotificationSound(audioPath!);
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId, // Re-create channel to force new audio settings
      'Execu Alarms',
      channelDescription: 'Channel for Execu application task and habit alarms',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm, // Force use of Android's Alarm Volume stream
      icon: '@mipmap/ic_launcher',
      sound: sound,
      // FLAG_INSISTENT (4) tells Android to loop the notification sound continuously until dismissed
      additionalFlags: Int32List.fromList(<int>[4]),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'snooze_alarm',
          'Snooze 10m',
          cancelNotification: true, // Automatically clears notification and stops the loop
        ),
        AndroidNotificationAction(
          'dismiss_alarm',
          'Dismiss',
          cancelNotification: true, // Automatically clears notification and stops the loop
        ),
      ],
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
      payload: id.toString(), // Passes the unique habit/alarm ID to the UI
    );
  }

  // Public method to schedule an alarm at a specific date/time
  static Future<void> setAlarm(int id, DateTime targetTime, {String? customTonePath}) async {
    if (targetTime.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) return;

    String channelId = 'execu_alarm_channel_id_v6';
    AndroidNotificationSound sound = const RawResourceAndroidNotificationSound('alarm');

    // ✅ Absolute target location verification check logic
    bool useCustomAudio = false;
    if (customTonePath != null && customTonePath.isNotEmpty) {
      if (await File(customTonePath).exists()) {
        useCustomAudio = true;
      }
    }

    if (useCustomAudio) {
      channelId = 'execu_alarm_channel_${customTonePath.hashCode}';
      // ✅ FIX: Pass raw path string without adding structural prefix breaks parsing schemes
      sound = UriAndroidNotificationSound(customTonePath!);
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      'Execu Alarms',
      channelDescription: 'Channel for Execu application task and habit alarms',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      icon: '@mipmap/ic_launcher',
      sound: sound,
      additionalFlags: Int32List.fromList(<int>[4]),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction('snooze_alarm', 'Snooze 10m', cancelNotification: true),
        AndroidNotificationAction('dismiss_alarm', 'Dismiss', cancelNotification: true),
      ],
    );

    final NotificationDetails generalDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentSound: true, presentAlert: true),
    );

    // Skips the buggy background isolates and natively schedules the looping alarm directly
    await _notificationsPlugin.zonedSchedule(
      id,
      '⏰ Execu Reminder!',
      'It is time to complete your scheduled focus session or habit!',
      tz.TZDateTime.from(targetTime, tz.local),
      generalDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Automatically repeats daily
      payload: '$id|${customTonePath ?? ""}',
    );
  }

  // Cancel an alarm if user deletes or switches off a task/habit reminder
  static Future<void> cancelAlarm(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // Reschedule all active habit alarms (call this on app startup/resume to handle time zone changes)
  static Future<void> rescheduleAllAlarms() async {
    await Hive.initFlutter();
    final box = await Hive.openBox('habits');
    
    final now = DateTime.now();

    for (var habit in box.values) {
      final map = Map<String, dynamic>.from(habit);
      final alarmId = map['alarmId'] as int?;
      final reminderStr = map['reminderTime'] as String?;
      final customTonePath = map['customTonePath'] as String?;

      if (alarmId != null && reminderStr != null) {
        final parsedTime = DateTime.tryParse(reminderStr);
        if (parsedTime != null) {
          var targetDateTime = DateTime(
            now.year, now.month, now.day,
            parsedTime.hour, parsedTime.minute,
          );
          
          if (targetDateTime.isBefore(now)) {
            targetDateTime = targetDateTime.add(const Duration(days: 1));
          }
          
          await setAlarm(alarmId, targetDateTime, customTonePath: customTonePath);
        }
      }
    }
  }

  // Schedules or updates a 9:00 PM daily summary notification
  static Future<void> updateDailySummary(int completed, int total) async {
    final now = DateTime.now();
    var targetTime = DateTime(now.year, now.month, now.day, 21, 0); // 9:00 PM
    
    if (targetTime.isBefore(now)) {
      targetTime = targetTime.add(const Duration(days: 1));
      completed = 0; 
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_summary_channel',
      'Daily Summary',
      channelDescription: 'Evening summary of completed habits',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails generalDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    String body = completed == 0 
      ? 'Time to wind down! Tap to log any habits you completed today.' 
      : 'Great job! You completed $completed out of $total habits today.';

    await _notificationsPlugin.zonedSchedule(
      9999, 
      '🌙 Daily Review',
      body,
      tz.TZDateTime.from(targetTime, tz.local),
      generalDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    final tomorrow = targetTime.add(const Duration(days: 1));
    await _notificationsPlugin.zonedSchedule(
      10000, 
      '🌙 Daily Review',
      'Time to wind down! Did you forget to log your habits today?',
      tz.TZDateTime.from(tomorrow, tz.local),
      generalDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}