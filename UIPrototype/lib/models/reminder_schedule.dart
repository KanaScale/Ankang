import 'reminder_model.dart';

/// 提醒调度规则的单一来源，供今日待办和全部提醒管理共同使用。
class ReminderSchedule {
  const ReminderSchedule._();

  /// 判断提醒是否应出现在指定日期的“今日待办”中。
  static bool isDueToday(ReminderModel reminder, {DateTime? now}) {
    if (!reminder.enabled) return false;

    final today = _dateOnly(now ?? DateTime.now());
    final startDate = _dateOnly(reminder.remindAt);
    if (today.isBefore(startDate)) return false;

    return switch (reminder.repeatType) {
      ReminderRepeatType.once => today == startDate,
      ReminderRepeatType.daily => true,
      ReminderRepeatType.weekly => today.weekday == startDate.weekday,
    };
  }

  /// 过期仅描述未完成的历史单次提醒；重复提醒会继续产生后续计划。
  static bool isExpiredOnce(ReminderModel reminder, {DateTime? now}) {
    final currentDate = _dateOnly(now ?? DateTime.now());
    return reminder.repeatType == ReminderRepeatType.once &&
        !reminder.completed &&
        _dateOnly(reminder.remindAt).isBefore(currentDate);
  }

  /// 计算下一次触发时间。完成的重复提醒从下一个周期继续计算。
  static DateTime? nextOccurrence(
    ReminderModel reminder, {
    DateTime? now,
    bool includeDisabled = false,
  }) {
    if (!reminder.enabled && !includeDisabled) return null;

    final current = now ?? DateTime.now();
    return switch (reminder.repeatType) {
      ReminderRepeatType.once =>
        !reminder.completed && !reminder.remindAt.isBefore(current)
            ? reminder.remindAt
            : null,
      ReminderRepeatType.daily => _nextDaily(reminder, current),
      ReminderRepeatType.weekly => _nextWeekly(reminder, current),
    };
  }

  /// 全部提醒默认顺序：可继续触发的启用项、历史启用项、停用项。
  static int compareForManagement(
    ReminderModel left,
    ReminderModel right, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final leftNext = nextOccurrence(
      left,
      now: current,
      includeDisabled: true,
    );
    final rightNext = nextOccurrence(
      right,
      now: current,
      includeDisabled: true,
    );
    final leftGroup = _managementGroup(left, leftNext);
    final rightGroup = _managementGroup(right, rightNext);
    if (leftGroup != rightGroup) return leftGroup.compareTo(rightGroup);

    if (leftGroup == 1) {
      // 历史单次提醒把较新的记录放在前面，方便用户重新安排。
      return right.remindAt.compareTo(left.remindAt);
    }
    if (leftNext != null && rightNext != null) {
      final byNextTime = leftNext.compareTo(rightNext);
      if (byNextTime != 0) return byNextTime;
    } else if (leftNext != null) {
      return -1;
    } else if (rightNext != null) {
      return 1;
    }
    return left.remindAt.compareTo(right.remindAt);
  }

  static DateTime _nextDaily(ReminderModel reminder, DateTime now) {
    if (now.isBefore(reminder.remindAt)) return reminder.remindAt;

    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.remindAt.hour,
      reminder.remindAt.minute,
    );
    if (candidate.isBefore(now) || reminder.completed) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static DateTime _nextWeekly(ReminderModel reminder, DateTime now) {
    if (now.isBefore(reminder.remindAt)) return reminder.remindAt;

    final daysUntilDue = (reminder.remindAt.weekday - now.weekday + 7) % 7;
    var candidate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilDue,
      reminder.remindAt.hour,
      reminder.remindAt.minute,
    );
    if (candidate.isBefore(reminder.remindAt)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 7));
    } else if (reminder.completed && _isSameDate(candidate, now)) {
      // weekly 的完成状态只覆盖当前周；若本周计划已经过去，候选值本身就是下周。
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  static int _managementGroup(ReminderModel reminder, DateTime? next) {
    if (!reminder.enabled) return 2;
    return next == null ? 1 : 0;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _isSameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
