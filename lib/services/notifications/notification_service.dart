/// Local (on-device) scheduled notifications — no server/push
/// infrastructure. Uses flutter_local_notifications + timezone for
/// correct daily local-time scheduling.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/logger.dart';

/// Stable ids — one per notification category, so re-scheduling one never
/// duplicates or clobbers another.
class NotificationIds {
  NotificationIds._();
  static const dailyAyah = 1;
  static const dailyDua = 2;
  static const todaysEncounter = 3;
  static const learningReminder = 4;
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _tag = 'NotificationService';

  /// Android notification channel. The id is user-visible in system settings,
  /// where it groups these reminders under the app.
  static const _channelId = 'mizan_daily';
  static const _channelName = 'Daily reminders';

  /// The channel id used while the app was called Taddabur. Android keeps a
  /// channel registered forever once created, so leaving this behind would
  /// have shown the user two identical "Daily reminders" entries in system
  /// settings — one of them dead. It is deleted in [init], which runs before
  /// anything is scheduled, so no pending alarm is ever left pointing at it:
  /// `NotificationPreferencesController._load` re-arms every category on each
  /// launch using the same stable ids, which replaces the old alarms outright.
  static const _legacyChannelId = 'taddabur_daily';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      AppLogger.error('Could not resolve device timezone', error: e, tag: _tag);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
          android: androidInit, iOS: iosInit),
    );
    await _deleteLegacyChannel();
    _initialized = true;
  }

  Future<void> _deleteLegacyChannel() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.deleteNotificationChannel(channelId: _legacyChannelId);
    } catch (e) {
      // Cosmetic cleanup only — never worth failing init over.
      AppLogger.error('Could not delete legacy notification channel',
          error: e, tag: _tag);
    }
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted =
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact — delivers within a short window without needing the
      // SCHEDULE_EXACT_ALARM permission. Fine for a daily reminder.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();
}
