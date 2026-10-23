import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ankang_assistant/pages/reminders/reminder_date_picker.dart';
import 'package:ankang_assistant/pages/reminders/reminder_time_picker.dart';

class _PickerHost extends StatelessWidget {
  const _PickerHost({
    required this.initialDate,
    required this.initialTime,
  });

  final DateTime initialDate;
  final TimeOfDay initialTime;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => showReminderDatePicker(
                  context,
                  initialDate: initialDate,
                ),
                child: const Text('选择日期'),
              ),
              TextButton(
                onPressed: () => showReminderTimePicker(
                  context,
                  initialTime: initialTime,
                ),
                child: const Text('选择时间'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('日期轮盘吸附中心项并显示本年摘要', (tester) async {
    final today = DateTime.now();
    await tester.pumpWidget(
      _PickerHost(
        initialDate: today,
        initialTime: const TimeOfDay(hour: 9, minute: 30),
      ),
    );

    await tester.tap(find.text('选择日期'));
    await tester.pumpAndSettle();

    final wheel = tester.widget<ListWheelScrollView>(
      find.byKey(const ValueKey('reminder-date-wheel')),
    );
    expect(wheel.physics, isA<FixedExtentScrollPhysics>());
    expect(
      find.text(
        '${today.month}月${today.day}日 · ${_weekday(today.weekday)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('日期轮盘跨年时摘要包含年份', (tester) async {
    final now = DateTime.now();
    final nextYear = DateTime(now.year + 1, 1, 1);
    if (nextYear.difference(DateTime(now.year, now.month, now.day)).inDays >
        365) {
      return;
    }
    await tester.pumpWidget(
      _PickerHost(
        initialDate: nextYear,
        initialTime: const TimeOfDay(hour: 9, minute: 30),
      ),
    );

    await tester.tap(find.text('选择日期'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '${nextYear.year}年1月1日 · ${_weekday(nextYear.weekday)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('小时和分钟轮盘分别使用固定项吸附', (tester) async {
    await tester.pumpWidget(
      _PickerHost(
        initialDate: DateTime.now(),
        initialTime: const TimeOfDay(hour: 19, minute: 54),
      ),
    );

    await tester.tap(find.text('选择时间'));
    await tester.pumpAndSettle();

    final wheels = tester
        .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView));
    expect(wheels, hasLength(2));
    for (final wheel in wheels) {
      expect(wheel.physics, isA<FixedExtentScrollPhysics>());
    }
    expect(find.byKey(const ValueKey('reminder-time-wheel-时')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-time-wheel-分')), findsOneWidget);
  });
}

String _weekday(int weekday) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday - 1];
