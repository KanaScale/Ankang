import 'package:ankang_assistant/widgets/care_mode_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('家属版状态提示不包含版本切换按钮', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CaregiverModeStatusBanner(),
          ),
        ),
      ),
    );

    expect(find.text('当前是家属版'), findsOneWidget);
    expect(find.textContaining('前往“照护”页'), findsOneWidget);
    expect(find.text('切回病人版'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
