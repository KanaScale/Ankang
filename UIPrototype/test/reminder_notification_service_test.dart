import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ankang_assistant/models/reminder_model.dart';
import 'package:ankang_assistant/models/reminder_notification_model.dart';
import 'package:ankang_assistant/services/reminder_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ankang_assistant/reminder_alarm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('schedules the next occurrence with its account owner', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });
    final reminder = ReminderModel(
      id: 17,
      title: '晚间服药',
      type: ReminderType.medicine,
      remindAt: DateTime(2026, 7, 24, 20),
      repeatType: ReminderRepeatType.daily,
    );

    await const ReminderNotificationService().schedule(
      ownerUserId: 9,
      reminder: reminder,
      now: DateTime(2026, 7, 24, 19),
    );

    expect(captured?.method, 'schedule');
    expect(captured?.arguments['ownerUserId'], 9);
    expect(captured?.arguments['reminderId'], 17);
    expect(
      captured?.arguments['triggerAtMillis'],
      reminder.remindAt.millisecondsSinceEpoch,
    );
  });

  test('cancels a disabled reminder instead of registering an alarm', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });
    final reminder = ReminderModel(
      id: 18,
      title: '停用提醒',
      type: ReminderType.other,
      remindAt: DateTime(2026, 7, 24, 20),
      repeatType: ReminderRepeatType.once,
      enabled: false,
    );

    await const ReminderNotificationService().schedule(
      ownerUserId: 9,
      reminder: reminder,
      now: DateTime(2026, 7, 24, 19),
    );

    expect(captured?.method, 'cancel');
    expect(captured?.arguments['ownerUserId'], 9);
    expect(captured?.arguments['reminderId'], 18);
  });

  test('offline reminder with a negative local id can be scheduled', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });
    final reminder = ReminderModel(
      id: -101,
      title: '离线提醒',
      type: ReminderType.other,
      remindAt: DateTime(2026, 7, 24, 20),
      repeatType: ReminderRepeatType.once,
    );

    await const ReminderNotificationService().schedule(
      ownerUserId: 9,
      reminder: reminder,
      now: DateTime(2026, 7, 24, 19),
    );

    expect(captured?.method, 'schedule');
    expect(captured?.arguments['reminderId'], -101);
  });

  test('parses a valid notification navigation target', () {
    final target = ReminderNotificationTarget.fromMap({
      'ownerUserId': 9,
      'reminderId': 17,
      'route': '/reminder',
    });

    expect(target.isValid, isTrue);
    expect(target.ownerUserId, 9);
    expect(target.reminderId, 17);
    expect(target.route, '/reminder');
  });

  test('reads and consumes the cold-start reminder target', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getInitialReminderLaunch') {
        return {
          'ownerUserId': 9,
          'reminderId': 17,
          'route': '/reminder',
        };
      }
      return null;
    });

    final target = await const ReminderNotificationService()
        .getInitialNotificationTarget();

    expect(target?.isValid, isTrue);
    expect(
      ReminderNotificationService.takePendingNavigation(9)?.reminderId,
      17,
    );
    expect(ReminderNotificationService.takePendingNavigation(9), isNull);
  });
}
