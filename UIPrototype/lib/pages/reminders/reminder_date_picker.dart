import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../widgets/common/common_button.dart';
import '../../widgets/glass_card.dart';

/// 与提醒时间入口保持一致的日期卡片。
class ReminderDatePickerCard extends StatelessWidget {
  const ReminderDatePickerCard({
    super.key,
    required this.date,
    required this.onTap,
  });

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.chartOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.chartOrange,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '日期',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(_dateCardValue(date),
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// 单列日期滚轮。
Future<DateTime?> showReminderDatePicker(
  BuildContext context, {
  required DateTime initialDate,
}) async {
  final today = _dateOnly(DateTime.now());
  final lastDate = today.add(const Duration(days: 365));
  final normalizedInitial = _dateOnly(initialDate);
  final safeInitial = normalizedInitial.isBefore(today)
      ? today
      : normalizedInitial.isAfter(lastDate)
          ? lastDate
          : normalizedInitial;
  final initialIndex = safeInitial.difference(today).inDays;
  final controller = FixedExtentScrollController(initialItem: initialIndex);
  var selectedIndex = initialIndex;

  final result = await showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final selectedDate = today.add(Duration(days: selectedIndex));
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('选择提醒日期',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Text(
                        _pickerDateSummary(selectedDate, today),
                        key: ValueKey(selectedIndex),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 216,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 76,
                            height: 64,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                ),
                              ),
                            ),
                          ),
                          ListWheelScrollView.useDelegate(
                            key: const ValueKey('reminder-date-wheel'),
                            controller: controller,
                            itemExtent: 64,
                            physics: const FixedExtentScrollPhysics(),
                            useMagnifier: true,
                            magnification: 1.08,
                            diameterRatio: 1.7,
                            onSelectedItemChanged: (index) =>
                                setDialogState(() => selectedIndex = index),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 366,
                              builder: (context, index) {
                                final date = today.add(Duration(days: index));
                                final selected = index == selectedIndex;
                                return Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 150),
                                    style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: selected
                                                  ? AppColors.primary
                                                  : AppColors.textTertiary,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ) ??
                                        const TextStyle(),
                                    child: Text(
                                      '${date.month}月${date.day}日  ${_weekdayLabel(date)}',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: CommonButton(
                            text: '取消',
                            type: CommonButtonType.secondary,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: CommonButton(
                            text: '确认',
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(selectedDate),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  controller.dispose();
  return result;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _relativeDateLabel(DateTime date) {
  final today = _dateOnly(DateTime.now());
  final difference = _dateOnly(date).difference(today).inDays;
  if (difference == 0) return '今天';
  if (difference == 1) return '明天';
  return '${date.month}月${date.day}日';
}

String _dateCardValue(DateTime date) {
  final relative = _relativeDateLabel(date);
  final calendar = '${date.month}月${date.day}日 ${_weekdayLabel(date)}';
  return relative == calendar.substring(0, calendar.indexOf(' '))
      ? calendar
      : '$relative · $calendar';
}

String _pickerDateSummary(DateTime date, DateTime today) {
  final datePart = date.year == today.year
      ? '${date.month}月${date.day}日'
      : '${date.year}年${date.month}月${date.day}日';
  return '$datePart · ${_weekdayLabel(date)}';
}

String _weekdayLabel(DateTime date) => switch (date.weekday) {
      DateTime.monday => '周一',
      DateTime.tuesday => '周二',
      DateTime.wednesday => '周三',
      DateTime.thursday => '周四',
      DateTime.friday => '周五',
      DateTime.saturday => '周六',
      DateTime.sunday => '周日',
      _ => '',
    };
