import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/reminder_model.dart';
import 'package:ankang_assistant/pages/reminders/reminder_list_page.dart';
import 'package:ankang_assistant/services/reminder_service.dart';

class _FakeReminderService extends ReminderService {
  _FakeReminderService({this.completed = false});

  final bool completed;
  bool uncompleteCalled = false;

  @override
  Future<BaseResponse<List<ReminderModel>>> getReminders() async {
    final now = DateTime.now();
    return BaseResponse(
      code: 200,
      message: 'success',
      success: true,
      data: [
        ReminderModel(
          id: 1,
          title: '服药',
          type: ReminderType.medicine,
          remindAt: DateTime(now.year, now.month, now.day, 8),
          repeatType: ReminderRepeatType.daily,
          completed: completed,
        ),
        ReminderModel(
          id: 2,
          title: '明日复诊',
          type: ReminderType.checkup,
          remindAt: DateTime(now.year, now.month, now.day + 1, 9),
          repeatType: ReminderRepeatType.once,
        ),
      ],
    );
  }

  @override
  Future<BaseResponse<void>> uncompleteReminder(int id) async {
    uncompleteCalled = true;
    return const BaseResponse(
      code: 200,
      message: 'success',
      success: true,
    );
  }
}

void main() {
  testWidgets('loads reminders through ReminderService', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ReminderListPage(service: _FakeReminderService())),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('今日待办'), findsOneWidget);
    expect(find.text('服药'), findsOneWidget);
    expect(find.text('明日复诊'), findsNothing);
    expect(find.byKey(const Key('all-reminders-entry')), findsOneWidget);
  });

  testWidgets('completed reminder can be marked incomplete again',
      (tester) async {
    final service = _FakeReminderService(completed: true);
    await tester.pumpWidget(
      MaterialApp(home: ReminderListPage(service: service)),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('取消服药的完成状态'));
    await tester.pump(const Duration(milliseconds: 240));

    expect(service.uncompleteCalled, isTrue);
    expect(find.text('已取消完成'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
