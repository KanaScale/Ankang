class ReminderNotificationReadiness {
  const ReminderNotificationReadiness({
    required this.supported,
    required this.notificationPermission,
    required this.exactAlarmAllowed,
  });

  const ReminderNotificationReadiness.unsupported()
      : supported = false,
        notificationPermission = 'unsupported',
        exactAlarmAllowed = false;

  final bool supported;
  final String notificationPermission;
  final bool exactAlarmAllowed;

  bool get canNotify => supported && notificationPermission == 'granted';

  factory ReminderNotificationReadiness.fromMap(
    Map<Object?, Object?> source,
  ) {
    return ReminderNotificationReadiness(
      supported: source['supported'] as bool? ?? false,
      notificationPermission:
          source['notificationPermission'] as String? ?? 'unsupported',
      exactAlarmAllowed: source['exactAlarmAllowed'] as bool? ?? false,
    );
  }
}

class ReminderNotificationEvent {
  const ReminderNotificationEvent({
    required this.ownerUserId,
    required this.reminderId,
    required this.title,
    required this.triggeredAt,
  });

  final int ownerUserId;
  final int reminderId;
  final String title;
  final DateTime triggeredAt;

  factory ReminderNotificationEvent.fromMap(
    Map<Object?, Object?> source,
  ) {
    final triggeredAtMillis = (source['triggeredAtMillis'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    return ReminderNotificationEvent(
      ownerUserId: (source['ownerUserId'] as num?)?.toInt() ?? 0,
      reminderId: (source['reminderId'] as num?)?.toInt() ?? 0,
      title: (source['title'] as String?)?.trim().isNotEmpty == true
          ? (source['title'] as String).trim()
          : '健康提醒',
      triggeredAt: DateTime.fromMillisecondsSinceEpoch(triggeredAtMillis),
    );
  }
}

class ReminderNotificationTarget {
  const ReminderNotificationTarget({
    required this.ownerUserId,
    required this.reminderId,
    this.route = '/reminder',
  });

  final int ownerUserId;
  final int reminderId;
  final String route;

  bool get isValid => ownerUserId > 0 && reminderId != 0;

  factory ReminderNotificationTarget.fromMap(
    Map<Object?, Object?> source,
  ) {
    return ReminderNotificationTarget(
      ownerUserId: (source['ownerUserId'] as num?)?.toInt() ?? 0,
      reminderId: (source['reminderId'] as num?)?.toInt() ?? 0,
      route: source['route'] as String? ?? '/reminder',
    );
  }
}
