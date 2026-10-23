import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/reminder_model.dart';
import '../models/user_model.dart';
import 'reminder_notification_service.dart';
import 'reminder_offline_repository.dart';
import 'emergency_contact_offline_repository.dart';

class OfflineSessionSnapshot {
  const OfflineSessionSnapshot({
    required this.ownerUserId,
    required this.generation,
  });

  final int? ownerUserId;
  final int generation;

  bool matches(int owner, int expectedGeneration) =>
      ownerUserId == owner && generation == expectedGeneration;
}

class OfflineSessionCoordinator {
  OfflineSessionCoordinator._();

  static final ValueNotifier<OfflineSessionSnapshot> session = ValueNotifier(
    const OfflineSessionSnapshot(ownerUserId: null, generation: 0),
  );

  static const ReminderNotificationService _notifications =
      ReminderNotificationService();
  static final ReminderOfflineRepository _reminders =
      ReminderOfflineRepository();
  static final EmergencyContactOfflineRepository _contacts =
      EmergencyContactOfflineRepository();
  static final ValueNotifier<bool> offlineState = ValueNotifier(false);

  static bool get isOfflineRestored => offlineState.value;

  static set isOfflineRestored(bool value) {
    if (offlineState.value != value) {
      offlineState.value = value;
    }
  }

  static Future<void> activate(
    UserModel user, {
    bool synchronize = true,
  }) async {
    isOfflineRestored = false;
    if (user.id <= 0) {
      await deactivate();
      return;
    }
    final previousOwner = session.value.ownerUserId;
    if (previousOwner != null && previousOwner != user.id) {
      await _notifications.cancelAll(previousOwner);
    }
    session.value = OfflineSessionSnapshot(
      ownerUserId: user.id,
      generation: session.value.generation + 1,
    );
    try {
      if (synchronize) {
        await _contacts.sync(user.id);
      }
      final reminders = synchronize
          ? (await _reminders.getReminders(user.id)).data
          : await _reminders.getCachedReminders(user.id);
      if (reminders != null && session.value.ownerUserId == user.id) {
        await _notifications.reconcile(
          ownerUserId: user.id,
          reminders: reminders,
        );
      }
    } catch (_) {
      // Login must remain available when notification reconciliation fails.
    }
  }

  static Future<void> deactivate() async {
    isOfflineRestored = false;
    final oldOwner = session.value.ownerUserId;
    session.value = OfflineSessionSnapshot(
      ownerUserId: null,
      generation: session.value.generation + 1,
    );
    if (oldOwner != null) {
      await _notifications.cancelAll(oldOwner);
    }
  }

  static Future<void> scheduleReminder(ReminderModel reminder) async {
    final owner = session.value.ownerUserId;
    if (owner == null) return;
    await _notifications.schedule(ownerUserId: owner, reminder: reminder);
  }

  static Future<void> cancelReminder(int reminderId) async {
    final owner = session.value.ownerUserId;
    if (owner == null) return;
    await _notifications.cancel(
      ownerUserId: owner,
      reminderId: reminderId,
    );
  }

  static Future<void> reconcileReminders(
    List<ReminderModel> reminders,
  ) async {
    final owner = session.value.ownerUserId;
    if (owner == null) return;
    await _notifications.reconcile(
      ownerUserId: owner,
      reminders: reminders,
    );
  }
}
