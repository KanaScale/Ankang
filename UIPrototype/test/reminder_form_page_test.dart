import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ankang_assistant/models/reminder_model.dart';
import 'package:ankang_assistant/pages/reminders/reminder_form_page.dart';

class _FormHost extends StatefulWidget {
  const _FormHost({required this.reminder});

  final ReminderModel reminder;

  @override
  State<_FormHost> createState() => _FormHostState();
}

class _FormHostState extends State<_FormHost> {
  String result = 'none';

  Future<void> _openForm() async {
    final value = await Navigator.of(context).push<ReminderFormResult>(
      MaterialPageRoute(
        builder: (_) => ReminderFormPage(initialReminder: widget.reminder),
      ),
    );
    if (!mounted) return;
    setState(() {
      result = switch (value) {
        ReminderFormSaved(:final reminder) =>
          'saved:${reminder.id}:${reminder.remark}:${reminder.completed}',
        ReminderFormDeleted(:final id) => 'deleted:$id',
        null => 'cancelled',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(result),
          TextButton(onPressed: _openForm, child: const Text('打开表单')),
        ],
      ),
    );
  }
}

ReminderModel _existingReminder() => ReminderModel(
      id: 7,
      title: '早晨服药',
      type: ReminderType.medicine,
      remindAt: DateTime(2026, 7, 16, 8, 30),
      repeatType: ReminderRepeatType.daily,
      completed: true,
      remark: '饭后服用',
    );

void main() {
  testWidgets('rejects a past one-time reminder time', (tester) async {
    final reminder = ReminderModel(
      id: 8,
      title: '过期提醒',
      type: ReminderType.other,
      remindAt: DateTime.now().subtract(const Duration(minutes: 5)),
      repeatType: ReminderRepeatType.once,
    );
    await tester.pumpWidget(MaterialApp(home: _FormHost(reminder: reminder)));
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.text('请选择未来时间'), findsOneWidget);
    expect(find.text('保存修改'), findsNothing);
    expect(find.text('saved:8:null:false'), findsNothing);
  });

  testWidgets('edit form prefills fields and can clear remark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: _FormHost(reminder: _existingReminder())),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();

    expect(find.text('编辑提醒'), findsOneWidget);
    expect(
      find.text('保存后可在应用内查看；在权限允许时可接收系统提醒。'),
      findsOneWidget,
    );
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.text('早晨服药'), findsOneWidget);
    expect(find.text('饭后服用'), findsOneWidget);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    await tester.enterText(find.byWidget(fields.last), '');
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    expect(find.text('saved:7:null:true'), findsOneWidget);
  });

  testWidgets('edit form requires confirmation before delete', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: _FormHost(reminder: _existingReminder())),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('删除提醒'));
    await tester.pumpAndSettle();
    expect(find.textContaining('删除后无法恢复'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(find.text('deleted:7'), findsOneWidget);
  });
}
