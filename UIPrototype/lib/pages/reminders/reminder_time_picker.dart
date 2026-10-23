import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../widgets/common/common_button.dart';
import '../../widgets/glass_card.dart';

/// 与新增提醒和编辑提醒共用的时间入口卡片。
class ReminderTimePickerCard extends StatelessWidget {
  const ReminderTimePickerCard({
    super.key,
    required this.time,
    required this.onTap,
    this.label = '提醒时间',
  });

  final TimeOfDay time;
  final VoidCallback onTap;
  final String label;

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
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child:
                const Icon(Icons.access_time_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(_formatTime(time),
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

/// 弹出循环时分滚轮，取消时返回 null。
Future<TimeOfDay?> showReminderTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) async {
  const cycles = 100;
  const hoursPerCycle = 24;
  const minutesPerCycle = 60;
  const hoursMid = (cycles ~/ 2) * hoursPerCycle;
  const minutesMid = (cycles ~/ 2) * minutesPerCycle;
  final hourController = FixedExtentScrollController();
  final minuteController = FixedExtentScrollController();
  var selectedHour = initialTime.hour;
  var selectedMinute = initialTime.minute;

  final result = await showDialog<TimeOfDay>(
    context: context,
    builder: (dialogContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        hourController.jumpToItem(hoursMid + selectedHour);
        minuteController.jumpToItem(minutesMid + selectedMinute);
      });

      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: StatefulBuilder(
              builder: (context, setDialogState) => Container(
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
                    Text('选择时间',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xl),
                    _TimeWheel(
                      hourController: hourController,
                      minuteController: minuteController,
                      selectedHour: selectedHour,
                      selectedMinute: selectedMinute,
                      onHourChanged: (hour) =>
                          setDialogState(() => selectedHour = hour),
                      onMinuteChanged: (minute) =>
                          setDialogState(() => selectedMinute = minute),
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
                            onPressed: () => Navigator.of(dialogContext).pop(
                              TimeOfDay(
                                hour: selectedHour,
                                minute: selectedMinute,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  hourController.dispose();
  minuteController.dispose();
  return result;
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required this.hourController,
    required this.minuteController,
    required this.selectedHour,
    required this.selectedMinute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final int selectedHour;
  final int selectedMinute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  static const _wheelHeight = 192.0;
  static const _itemExtent = 48.0;
  static const _centerTop = (_wheelHeight - _itemExtent) / 2;

  Widget _buildColumn({
    required BuildContext context,
    required FixedExtentScrollController controller,
    required int childCount,
    required String Function(int) textBuilder,
    required bool Function(int) isSelected,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Stack(
        children: [
          SizedBox(
            height: _wheelHeight,
            child: ListWheelScrollView.useDelegate(
              key: ValueKey('reminder-time-wheel-$unit'),
              controller: controller,
              itemExtent: _itemExtent,
              physics: const FixedExtentScrollPhysics(),
              useMagnifier: true,
              magnification: 1.08,
              diameterRatio: 1.7,
              onSelectedItemChanged: onChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: childCount,
                builder: (context, index) => Center(
                  child: Text(
                    textBuilder(index),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: isSelected(index)
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontWeight:
                              isSelected(index) ? FontWeight.w700 : null,
                        ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: _centerTop,
            left: 0,
            right: 0,
            height: _itemExtent,
            child: IgnorePointer(
              child: Align(
                alignment: const Alignment(0.5, 0),
                child: Text(
                  unit,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _wheelHeight,
      child: Stack(
        children: [
          Positioned(
            top: _centerTop,
            left: 0,
            right: 0,
            height: _itemExtent,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _buildColumn(
                context: context,
                controller: hourController,
                childCount: 100 * 24,
                textBuilder: (index) => '${index % 24}',
                isSelected: (index) => index % 24 == selectedHour,
                unit: '时',
                onChanged: (index) => onHourChanged(index % 24),
              ),
              SizedBox(
                height: _wheelHeight,
                child: Center(
                  child: Text(':',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(color: AppColors.textPrimary)),
                ),
              ),
              _buildColumn(
                context: context,
                controller: minuteController,
                childCount: 100 * 60,
                textBuilder: (index) => (index % 60).toString().padLeft(2, '0'),
                isSelected: (index) => index % 60 == selectedMinute,
                unit: '分',
                onChanged: (index) => onMinuteChanged(index % 60),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
