import 'dart:async';

import 'package:flutter/services.dart';

import '../models/reminder_model.dart';
import '../models/reminder_notification_model.dart';
import '../models/reminder_schedule.dart';

class ReminderNotificationService {
  const ReminderNotificationService();

  static const MethodChannel _channel =
      MethodChannel('ankang_assistant/reminder_alarm');
  static final StreamController<ReminderNotificationEvent>
      _foregroundEventController =
      StreamController<ReminderNotificationEvent>.broadcast();
  static final StreamController<ReminderNotificationTarget>
      _notificationTapController =
      StreamController<ReminderNotificationTarget>.broadcast();
  static bool _foregroundEventsInitialized = false;
  static ReminderNotificationTarget? _pendingNavigation;

  static Stream<ReminderNotificationEvent> get foregroundEvents {
    initializeForegroundEvents();
    return _foregroundEventController.stream;
  }

  static Stream<ReminderNotificationTarget> get notificationTaps {
    initializeForegroundEvents();
    return _notificationTapController.stream;
  }

  static void initializeForegroundEvents() {
    if (_foregroundEventsInitialized) return;
    _foregroundEventsInitialized = true;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments;
      if (arguments is! Map) return;
      final values = Map<Object?, Object?>.from(arguments);
      if (call.method == 'reminderTriggered') {
        final event = ReminderNotificationEvent.fromMap(values);
        if (event.ownerUserId <= 0 || event.reminderId == 0) return;
        _foregroundEventController.add(event);
      } else if (call.method == 'reminderOpened') {
        final target = ReminderNotificationTarget.fromMap(values);
        if (!target.isValid) return;
        rememberPendingNavigation(target);
        _notificationTapController.add(target);
      }
    });
  }

  Future<ReminderNotificationTarget?> getInitialNotificationTarget() async {
    initializeForegroundEvents();
    try {
      final values = await _channel.invokeMapMethod<Object?, Object?>(
        'getInitialReminderLaunch',
      );
      if (values == null) return null;
      final target = ReminderNotificationTarget.fromMap(values);
      if (!target.isValid) return null;
      rememberPendingNavigation(target);
      return target;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static void rememberPendingNavigation(ReminderNotificationTarget target) {
    if (target.isValid) _pendingNavigation = target;
  }

  static ReminderNotificationTarget? takePendingNavigation(int ownerUserId) {
    final target = _pendingNavigation;
    _pendingNavigation = null;
    if (target == null || target.ownerUserId != ownerUserId) return null;
    return target;
  }

  Future<ReminderNotificationReadiness> checkReadiness() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'checkReadiness',
      );
      return result == null
          ? const ReminderNotificationReadiness.unsupported()
          : ReminderNotificationReadiness.fromMap(result);
    } on MissingPluginException {
      return const ReminderNotificationReadiness.unsupported();
    } on PlatformException {
      return const ReminderNotificationReadiness.unsupported();
    }
  }

  Future<ReminderNotificationReadiness> requestPermission() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'requestPermission',
      );
      return result == null
          ? const ReminderNotificationReadiness.unsupported()
          : ReminderNotificationReadiness.fromMap(result);
    } on MissingPluginException {
      return const ReminderNotificationReadiness.unsupported();
    } on PlatformException {
      return checkReadiness();
    }
  }

  Future<bool> openExactAlarmSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openExactAlarmSettings') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> schedule({
    required int ownerUserId,
    required ReminderModel reminder,
    DateTime? now,
  }) async {
    final occurrence = ReminderSchedule.nextOccurrence(reminder, now: now);
    if (ownerUserId <= 0 || reminder.id == 0 || occurrence == null) {
      await cancel(ownerUserId: ownerUserId, reminderId: reminder.id);
      return;
    }
    try {
      await _channel.invokeMethod<bool>('schedule', {
        'ownerUserId': ownerUserId,
        'reminderId': reminder.id,
        'title': reminder.title,
        'triggerAtMillis': occurrence.millisecondsSinceEpoch,
        'repeatType': reminder.repeatType.name,
      });
    } on MissingPluginException {
      // Web and unsupported platforms keep the in-app reminder experience.
    }
  }

  Future<void> cancel({
    required int ownerUserId,
    required int reminderId,
  }) async {
    if (ownerUserId <= 0 || reminderId == 0) return;
    try {
      await _channel.invokeMethod<bool>('cancel', {
        'ownerUserId': ownerUserId,
        'reminderId': reminderId,
      });
    } on MissingPluginException {
      // Unsupported platforms have no native alarm to cancel.
    }
  }

  Future<void> cancelAll(int ownerUserId) async {
    if (ownerUserId <= 0) return;
    try {
      await _channel.invokeMethod<bool>(
        'cancelAll',
        {'ownerUserId': ownerUserId},
      );
    } on MissingPluginException {
      // Unsupported platforms have no native alarms to cancel.
    }
  }

  Future<void> reconcile({
    required int ownerUserId,
    required List<ReminderModel> reminders,
    DateTime? now,
  }) async {
    await cancelAll(ownerUserId);
    for (final reminder in reminders) {
      await schedule(
        ownerUserId: ownerUserId,
        reminder: reminder,
        now: now,
      );
    }
  }
}
