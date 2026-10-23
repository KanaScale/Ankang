import 'package:flutter_test/flutter_test.dart';

import 'package:ankang_assistant/models/reminder_model.dart';
import 'package:ankang_assistant/models/reminder_schedule.dart';

ReminderModel reminder({
  required int id,
  required DateTime remindAt,
  ReminderRepeatType repeatType = ReminderRepeatType.once,
  bool enabled = true,
  bool completed = false,
}) {
  return ReminderModel(
    id: id,
    title: '提醒 $id',
    type: ReminderType.other,
    remindAt: remindAt,
    repeatType: repeatType,
    enabled: enabled,
    completed: completed,
  );
}

void main() {
  final now = DateTime(2026, 7, 16, 10);

  test('today rules cover once daily weekly and disabled reminders', () {
    expect(
      ReminderSchedule.isDueToday(
        reminder(id: 1, remindAt: DateTime(2026, 7, 16, 8)),
        now: now,
      ),
      isTrue,
    );
    expect(
      ReminderSchedule.isDueToday(
        reminder(
          id: 2,
          remindAt: DateTime(2026, 7, 15, 8),
          repeatType: ReminderRepeatType.daily,
        ),
        now: now,
      ),
      isTrue,
    );
    expect(
      ReminderSchedule.isDueToday(
        reminder(
          id: 3,
          remindAt: DateTime(2026, 7, 9, 8),
          repeatType: ReminderRepeatType.weekly,
        ),
        now: now,
      ),
      isTrue,
    );
    expect(
      ReminderSchedule.isDueToday(
        reminder(
          id: 4,
          remindAt: DateTime(2026, 7, 16, 8),
          enabled: false,
        ),
        now: now,
      ),
      isFalse,
    );
  });

  test('future start dates do not enter today', () {
    for (final repeatType in ReminderRepeatType.values) {
      expect(
        ReminderSchedule.isDueToday(
          reminder(
            id: repeatType.index,
            remindAt: DateTime(2026, 7, 17, 8),
            repeatType: repeatType,
          ),
          now: now,
        ),
        isFalse,
      );
    }
  });

  test('completed recurring reminder advances to the next period', () {
    final daily = reminder(
      id: 1,
      remindAt: DateTime(2026, 7, 1, 8),
      repeatType: ReminderRepeatType.daily,
      completed: true,
    );
    final weekly = reminder(
      id: 2,
      remindAt: DateTime(2026, 7, 9, 8),
      repeatType: ReminderRepeatType.weekly,
      completed: true,
    );

    expect(
      ReminderSchedule.nextOccurrence(daily, now: now),
      DateTime(2026, 7, 17, 8),
    );
    expect(
      ReminderSchedule.nextOccurrence(weekly, now: now),
      DateTime(2026, 7, 23, 8),
    );
  });

  test('management sort keeps active, historical, and disabled groups', () {
    final active = reminder(
      id: 1,
      remindAt: DateTime(2026, 7, 17, 8),
    );
    final expired = reminder(
      id: 2,
      remindAt: DateTime(2026, 7, 15, 8),
    );
    final disabled = reminder(
      id: 3,
      remindAt: DateTime(2026, 7, 14, 8),
      enabled: false,
    );
    final items = [disabled, expired, active]
      ..sort((left, right) => ReminderSchedule.compareForManagement(
            left,
            right,
            now: now,
          ));

    expect(items.map((item) => item.id), [1, 2, 3]);
    expect(ReminderSchedule.isExpiredOnce(expired, now: now), isTrue);
  });

  test('copyWith can explicitly clear an existing remark', () {
    final source = ReminderModel(
      id: 1,
      title: '服药',
      type: ReminderType.medicine,
      remindAt: now,
      repeatType: ReminderRepeatType.daily,
      remark: '饭后服用',
    );

    expect(source.copyWith().remark, '饭后服用');
    expect(source.copyWith(remark: null).remark, isNull);
  });
}
