import 'package:ankang_assistant/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers all public page routes', () {
    expect(
        AppRoutes.routes.keys,
        containsAll(<String>[
          AppRoutes.login,
          AppRoutes.sessionGate,
          AppRoutes.register,
          AppRoutes.forgotPassword,
          AppRoutes.home,
          AppRoutes.profile,
          AppRoutes.records,
          AppRoutes.reminders,
          AppRoutes.emergency,
          AppRoutes.family,
          AppRoutes.familyAgent,
          AppRoutes.reports,
        ]));
  });

  testWidgets('unknown route shows fallback page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateInitialRoutes: AppRoutes.onGenerateInitialRoutes,
        onUnknownRoute: AppRoutes.onUnknownRoute,
        initialRoute: '/missing',
      ),
    );

    expect(find.text('页面不存在'), findsOneWidget);
    expect(find.text('未找到路由：/missing'), findsOneWidget);
  });
}
