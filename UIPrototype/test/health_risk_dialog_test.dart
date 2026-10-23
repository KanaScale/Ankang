import 'package:ankang_assistant/models/health_event_model.dart';
import 'package:ankang_assistant/widgets/health_risk_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HealthEventModel highRiskEvent() => HealthEventModel.fromJson({
        'eventId': 'event-1',
        'healthRecordId': 88,
        'status': 'completed',
        'riskLevel': 'high',
        'riskScore': 100,
        'summary': '建议立即关注并评估是否进入 SOS',
        'reasons': ['血压明显偏高', '心率处于偏快状态'],
      });

  testWidgets('shows reasons and returns selected risk action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    HealthRiskAction? result;
    final event = highRiskEvent();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showHealthRiskDialog(context, event);
              },
              child: const Text('打开风险提示'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开风险提示'));
    await tester.pumpAndSettle();

    expect(find.text('检测到较高健康风险'), findsOneWidget);
    expect(find.text('血压明显偏高'), findsOneWidget);
    expect(find.text('心率处于偏快状态'), findsOneWidget);
    expect(find.text('查看趋势'), findsOneWidget);
    expect(find.text('咨询 Agent'), findsNothing);
    expect(find.text('进入 SOS'), findsOneWidget);
    expect(find.text('处理时间线'), findsNothing);

    await tester.tap(find.text('查看趋势'));
    await tester.pumpAndSettle();
    expect(result, HealthRiskAction.trend);
  });

  testWidgets('uses full-width action buttons on a narrow phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: const Size(390, 844)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showHealthRiskDialog(context, highRiskEvent()),
              child: const Text('打开风险提示'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开风险提示'));
    await tester.pumpAndSettle();

    final trend = tester.getRect(find.widgetWithText(OutlinedButton, '查看趋势'));
    final sos = tester.getRect(find.widgetWithText(FilledButton, '进入 SOS'));

    expect(sos.top, greaterThan(trend.bottom));
    expect(trend.width, greaterThan(250));
    expect(sos.width, greaterThan(250));
  });
}
