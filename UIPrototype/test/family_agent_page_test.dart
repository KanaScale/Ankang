import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ankang_assistant/app/design_tokens.dart';
import 'package:ankang_assistant/models/agent_chat_model.dart';
import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/family_models.dart';
import 'package:ankang_assistant/pages/family/family_agent_page.dart';
import 'package:ankang_assistant/services/family_service.dart';
import 'package:ankang_assistant/widgets/glass_card.dart';

class _ChatCall {
  const _ChatCall({
    required this.patientId,
    required this.message,
    required this.sessionId,
  });

  final int patientId;
  final String message;
  final int? sessionId;
}

class _FakeFamilyService extends FamilyService {
  final calls = <_ChatCall>[];

  @override
  Future<BaseResponse<AgentReplyModel>> familyAgentChat({
    required int patientId,
    required String message,
    int? sessionId,
  }) async {
    calls.add(
      _ChatCall(
        patientId: patientId,
        message: message,
        sessionId: sessionId,
      ),
    );
    return const BaseResponse<AgentReplyModel>(
      code: 200,
      message: 'success',
      success: true,
      data: AgentReplyModel(
        sessionId: 42,
        answer: '请继续关注血压变化。',
      ),
    );
  }
}

const _patient = BoundPatientModel(
  patientUserId: 7,
  patientName: '李阿姨',
);

Widget _buildPage(
  FamilyService service, {
  double keyboardInset = 0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(430, 900),
        viewInsets: EdgeInsets.only(bottom: keyboardInset),
      ),
      child: FamilyAgentPage(
        patient: _patient,
        service: service,
      ),
    ),
  );
}

void main() {
  testWidgets('家属版输入框使用透明无边框玻璃样式', (tester) async {
    await tester.pumpWidget(_buildPage(_FakeFamilyService()));
    await tester.pump();

    expect(find.text('李阿姨 · Agent'), findsOneWidget);
    expect(find.text('输入照护问题'), findsOneWidget);

    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('family_agent_message_input')),
    );
    expect(input.minLines, 1);
    expect(input.maxLines, 4);
    expect(input.textInputAction, TextInputAction.send);
    expect(input.decoration?.border, InputBorder.none);
    expect(input.decoration?.enabledBorder, InputBorder.none);
    expect(input.decoration?.focusedBorder, InputBorder.none);
    expect(input.decoration?.filled, isFalse);
    expect(input.decoration?.contentPadding, EdgeInsets.zero);

    final glassCard = tester.widget<GlassCard>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('family_agent_message_input')),
            matching: find.byType(GlassCard),
          )
          .first,
    );
    expect(glassCard.blur, 22);
    expect(glassCard.opacity, 0.78);
    expect(glassCard.borderRadius, AppRadius.xxl);
  });

  testWidgets('键盘出现时隐藏快捷问题并上移输入框', (tester) async {
    final service = _FakeFamilyService();
    await tester.pumpWidget(_buildPage(service));
    await tester.pump();

    var promptHeader = tester.widget<AnimatedAlign>(
      find.byKey(const ValueKey('family_agent_prompt_header')),
    );
    var promptPointer = tester.widget<IgnorePointer>(
      find
          .descendant(
            of: find.byKey(const ValueKey('family_agent_prompt_header')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(promptHeader.heightFactor, 1);
    expect(promptPointer.ignoring, isFalse);

    await tester.pumpWidget(_buildPage(service, keyboardInset: 320));
    await tester.pump();

    promptHeader = tester.widget<AnimatedAlign>(
      find.byKey(const ValueKey('family_agent_prompt_header')),
    );
    promptPointer = tester.widget<IgnorePointer>(
      find
          .descendant(
            of: find.byKey(const ValueKey('family_agent_prompt_header')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(promptHeader.heightFactor, 0);
    expect(promptPointer.ignoring, isTrue);

    final composerPosition = tester.widget<Positioned>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('family_agent_message_composer')),
            matching: find.byType(Positioned),
          )
          .first,
    );
    expect(composerPosition.bottom, AppSpacing.sm);
  });

  testWidgets('发送问题后复用会话并展示回复', (tester) async {
    final service = _FakeFamilyService();
    await tester.pumpWidget(_buildPage(service));
    await tester.pump();

    final input = find.byKey(const ValueKey('family_agent_message_input'));
    await tester.enterText(input, ' 最近血压怎么样？ ');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(service.calls, hasLength(1));
    expect(service.calls.single.patientId, 7);
    expect(service.calls.single.message, '最近血压怎么样？');
    expect(service.calls.single.sessionId, isNull);
    expect(find.text('最近血压怎么样？'), findsOneWidget);
    expect(find.text('请继续关注血压变化。'), findsOneWidget);

    await tester.enterText(input, '今天吃药了吗？');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(service.calls, hasLength(2));
    expect(service.calls.last.sessionId, 42);
    expect(service.calls.last.message, '今天吃药了吗？');
  });
}
