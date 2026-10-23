import 'package:ankang_assistant/pages/home/home_page.dart';
import 'package:ankang_assistant/widgets/ios_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screenSize = Size(390, 844);

  Widget buildHome({double keyboardInset = 0}) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MediaQuery(
        data: const MediaQueryData(size: screenSize).copyWith(
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        ),
        child: const HomePage(),
      ),
    );
  }

  void configureScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = screenSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> finishEntranceAnimations(WidgetTester tester) {
    // The composer uses FadeSlideIn with a 140ms delay and a 520ms animation.
    return tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('keyboard hides navigation and collapses the chat header',
      (tester) async {
    configureScreen(tester);
    await tester.pumpWidget(buildHome(keyboardInset: 300));
    await finishEntranceAnimations(tester);

    expect(find.byType(IosBottomNavigation), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('agent_chat_header'))).height,
      0,
    );
  });

  testWidgets('composer stays 12dp above the resized keyboard viewport',
      (tester) async {
    configureScreen(tester);
    const keyboardInset = 300.0;
    await tester.pumpWidget(buildHome(keyboardInset: keyboardInset));
    await finishEntranceAnimations(tester);

    final composerBottom = tester
        .getRect(find.byKey(const ValueKey('agent_message_composer')))
        .bottom;
    final keyboardTop = screenSize.height - keyboardInset;

    expect(keyboardTop - composerBottom, 12);
  });

  testWidgets('keyboard dismissal restores header and bottom navigation',
      (tester) async {
    configureScreen(tester);
    await tester.pumpWidget(buildHome(keyboardInset: 300));
    await finishEntranceAnimations(tester);

    await tester.pumpWidget(buildHome());
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(IosBottomNavigation), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('agent_chat_header'))).height,
      greaterThan(0),
    );

    final composerBottom = tester
        .getRect(find.byKey(const ValueKey('agent_message_composer')))
        .bottom;
    expect(screenSize.height - composerBottom, 104);
  });
}
