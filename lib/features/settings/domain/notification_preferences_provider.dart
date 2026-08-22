/// Notification preferences — persisted locally, wired to real scheduled
/// notifications via NotificationService. No server/push involved.
library;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/notifications/notification_service.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.masterEnabled = false,
    this.dailyAyah = true,
    this.dailyDua = true,
    this.todaysEncounter = true,
    this.learningReminder = false,
    this.hour = 7,
    this.minute = 0,
  });

  final bool masterEnabled;
  final bool dailyAyah;
  final bool dailyDua;
  final bool todaysEncounter;
  final bool learningReminder;
  final int hour;
  final int minute;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  NotificationPreferences copyWith({
    bool? masterEnabled,
    bool? dailyAyah,
    bool? dailyDua,
    bool? todaysEncounter,
    bool? learningReminder,
    int? hour,
    int? minute,
  }) =>
      NotificationPreferences(
        masterEnabled: masterEnabled ?? this.masterEnabled,
        dailyAyah: dailyAyah ?? this.dailyAyah,
        dailyDua: dailyDua ?? this.dailyDua,
        todaysEncounter: todaysEncounter ?? this.todaysEncounter,
        learningReminder: learningReminder ?? this.learningReminder,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

class NotificationPreferencesController
    extends StateNotifier<NotificationPreferences> {
  NotificationPreferencesController() : super(const NotificationPreferences()) {
    _load();
  }

  static const _kMaster = 'notif_master';
  static const _kAyah = 'notif_ayah';
  static const _kDua = 'notif_dua';
  static const _kEncounter = 'notif_encounter';
  static const _kLearning = 'notif_learning';
  static const _kHour = 'notif_hour';
  static const _kMinute = 'notif_minute';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = NotificationPreferences(
      masterEnabled: p.getBool(_kMaster) ?? false,
      dailyAyah: p.getBool(_kAyah) ?? true,
      dailyDua: p.getBool(_kDua) ?? true,
      todaysEncounter: p.getBool(_kEncounter) ?? true,
      learningReminder: p.getBool(_kLearning) ?? false,
      hour: p.getInt(_kHour) ?? 7,
      minute: p.getInt(_kMinute) ?? 0,
    );
    if (state.masterEnabled) await _applySchedule();
  }

  Future<void> setMaster(bool value) async {
    state = state.copyWith(masterEnabled: value);
    await (await SharedPreferences.getInstance()).setBool(_kMaster, value);
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        state = state.copyWith(masterEnabled: false);
        await (await SharedPreferences.getInstance())
            .setBool(_kMaster, false);
        return;
      }
      await _applySchedule();
    } else {
      await NotificationService.instance.cancelAll();
    }
  }

  Future<void> setCategory({
    bool? dailyAyah,
    bool? dailyDua,
    bool? todaysEncounter,
    bool? learningReminder,
  }) async {
    state = state.copyWith(
      dailyAyah: dailyAyah,
      dailyDua: dailyDua,
      todaysEncounter: todaysEncounter,
      learningReminder: learningReminder,
    );
    final p = await SharedPreferences.getInstance();
    if (dailyAyah != null) await p.setBool(_kAyah, dailyAyah);
    if (dailyDua != null) await p.setBool(_kDua, dailyDua);
    if (todaysEncounter != null) await p.setBool(_kEncounter, todaysEncounter);
    if (learningReminder != null) await p.setBool(_kLearning, learningReminder);
    if (state.masterEnabled) await _applySchedule();
  }

  Future<void> setTime(TimeOfDay time) async {
    state = state.copyWith(hour: time.hour, minute: time.minute);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kHour, time.hour);
    await p.setInt(_kMinute, time.minute);
    if (state.masterEnabled) await _applySchedule();
  }

  Future<void> _applySchedule() async {
    final svc = NotificationService.instance;

    Future<void> apply(bool enabled, int id, String title, String body) async {
      if (enabled) {
        await svc.scheduleDaily(
          id: id,
          title: title,
          body: body,
          hour: state.hour,
          minute: state.minute,
        );
      } else {
        await svc.cancel(id);
      }
    }

    await apply(state.dailyAyah, NotificationIds.dailyAyah,
        'Ayah to sit with', 'Today\'s ayah is ready for you in Taddabur.');
    await apply(state.dailyDua, NotificationIds.dailyDua, 'Daily Dua',
        'Today\'s dua is ready for you in Taddabur.');
    await apply(state.todaysEncounter, NotificationIds.todaysEncounter,
        "Today's Encounter", 'A new discovery is waiting in Taddabur.');
    await apply(state.learningReminder, NotificationIds.learningReminder,
        'Continue your journey', 'Pick up where you left off in Taddabur.');
  }
}

final notificationPreferencesProvider = StateNotifierProvider<
    NotificationPreferencesController, NotificationPreferences>(
  (ref) => NotificationPreferencesController(),
);
