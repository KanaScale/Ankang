import 'package:ankang_assistant/models/agent_action.dart';
import 'package:ankang_assistant/models/agent_chat_model.dart';
import 'package:ankang_assistant/widgets/agent_action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AgentReplyModel parses pendingAction', () {
    final reply = AgentReplyModel.fromJson({
      'sessionId': 12,
      'answer': '请确认',
      'pendingAction': {
        'actionId': 'act_1',
        'actionType': 'RECORD_HEALTH_DATA',
        'title': '确认录入健康数据',
        'description': '血压 160/100',
        'requiresConfirmation': true,
        'status': 'PENDING_CONFIRMATION',
        'payload': {
          'systolic': 160,
          'diastolic': 100,
        },
      },
    });

    expect(reply.pendingAction?.actionId, 'act_1');
    expect(reply.pendingAction?.pending, isTrue);
    expect(reply.pendingAction?.payload['systolic'], 160);
  });

  testWidgets('AgentActionCard confirms action and shows result',
      (tester) async {
    var called = false;
    final action = AgentActionModel.fromJson({
      'actionId': 'act_1',
      'actionType': 'RECORD_HEALTH_DATA',
      'title': '确认录入健康数据',
      'description': '血压 160/100',
      'status': 'PENDING_CONFIRMATION',
      'payload': {
        'systolic': 160,
        'diastolic': 100,
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentActionCard(
            action: action,
            onSubmit: (action, confirmed) async {
              called = confirmed && action.actionId == 'act_1';
              return AgentActionModel.fromJson({
                'actionId': 'act_1',
                'actionType': 'RECORD_HEALTH_DATA',
                'status': 'EXECUTED',
                'resultMessage': '健康数据已成功记录。',
                'payload': action.payload,
                'result': {
                  'risk': {
                    'riskLevel': 'high',
                    'riskScore': 78,
                    'summary': '血压明显偏高',
                    'reasons': ['血压明显偏高'],
                  },
                },
              });
            },
          ),
        ),
      ),
    );

    expect(find.text('确认录入健康数据'), findsOneWidget);
    expect(find.text('血压 160/100'), findsNWidgets(2));

    await tester.tap(find.text('确认录入'));
    await tester.pump();
    await tester.pump();

    expect(called, isTrue);
    expect(find.text('健康数据已成功记录。'), findsOneWidget);
    expect(find.text('高风险 · 78 分'), findsOneWidget);
  });
}
