import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/reminder_model.dart';
import 'package:ankang_assistant/pages/reminders/reminder_management_page.dart';
import 'package:ankang_assistant/services/reminder_service.dart';

class _FakeReminderService extends ReminderService {
  bool? lastEnabled;
  bool failUpdate = false;

  final reminders = <ReminderModel>[
    ReminderModel(
      id: 1,
      title: '每日服药',
      type: ReminderType.medicine,
      remindAt: DateTime(2026, 7, 1, 8),
      repeatType: ReminderRepeatType.daily,
    ),
    ReminderModel(
      id: 2,
      title: '暂停测量',
      type: ReminderType.bloodPressure,
      remindAt: DateTime(2026, 7, 1, 9),
      repeatType: ReminderRepeatType.daily,
      enabled: false,
    ),
  ];

  @override
  Future<BaseResponse<List<ReminderModel>>> getReminders() async =>
      BaseResponse(
        code: 200,
        message: 'success',
        success: true,
        data: List.of(reminders),
      );

  @override
  Future<BaseResponse<ReminderModel>> updateReminder(
    ReminderModel reminder,
  ) async {
    lastEnabled = reminder.enabled;
    if (failUpdate) {
      return const BaseResponse(
        code: 500,
        message: '保存失败',
        success: false,
      );
    }
    return BaseResponse(
      code: 200,
      message: 'success',
      success: true,
      data: reminder,
    );
  }
}

void main() {
  testWidgets('filters all reminders by enabled status', (tester) async {
    final service = _FakeReminderService();
    await tester.pumpWidget(
      MaterialApp(home: ReminderManagementPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部提醒'), findsOneWidget);
    expect(find.text('每日服药'), findsOneWidget);
    expect(find.text('暂停测量'), findsOneWidget);

    await tester.tap(find.text('已停用 1'));
    await tester.pump();
    expect(find.text('每日服药'), findsNothing);
    expect(find.text('暂停测量'), findsOneWidget);
  });

  testWidgets('quick switch persists the new enabled state', (tester) async {
    final service = _FakeReminderService();
    await tester.pumpWidget(
      MaterialApp(home: ReminderManagementPage(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 240));

    expect(service.lastEnabled, isFalse);
    expect(find.text('提醒已停用'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('failed quick switch keeps the original state', (tester) async {
    final service = _FakeReminderService()..failUpdate = true;
    await tester.pumpWidget(
      MaterialApp(home: ReminderManagementPage(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text('保存失败'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    await tester.pumpAndSettle();
  });
}
