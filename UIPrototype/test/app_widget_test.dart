import 'package:ankang_assistant/app.dart';
import 'package:ankang_assistant/models/user_model.dart';
import 'package:ankang_assistant/routes/app_routes.dart';
import 'package:ankang_assistant/services/auth_service.dart';
import 'package:ankang_assistant/widgets/large_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on login page', (tester) async {
    await tester.pumpWidget(const AnkangAssistantApp());
    await tester.pumpAndSettle();

    expect(find.text('守护您的每一天健康'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('创建账号'), findsOneWidget);
    expect(find.text('忘记密码'), findsOneWidget);
    expect(find.text('保持登录'), findsOneWidget);
    expect(find.text('记住账号'), findsNothing);
    expect(find.text('自动登录'), findsNothing);
    expect(find.byType(LargePrimaryButton), findsOneWidget);
  });

  testWidgets('navigates from login page to register page', (tester) async {
    await tester.pumpWidget(const AnkangAssistantApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('创建账号'));
    await tester.tap(find.text('创建账号'));
    await tester.pumpAndSettle();

    expect(find.text('注册账号'), findsOneWidget);
    expect(find.text('提交注册'), findsOneWidget);
  });

  testWidgets('navigates from login page to forgot password page',
      (tester) async {
    await tester.pumpWidget(const AnkangAssistantApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('忘记密码'));
    await tester.pumpAndSettle();

    expect(find.text('重置登录密码'), findsOneWidget);
    expect(find.text('验证码'), findsOneWidget);
    expect(find.text('重置密码'), findsOneWidget);
  });

  testWidgets('home page renders Apple Health style navigation',
      (tester) async {
    AuthService.cacheCurrentUser(
      const UserModel(id: 1, username: 'zhangsan', nickname: '张三'),
    );
    addTearDown(() => AuthService.cacheCurrentUser(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.home,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('健康陪伴'), findsOneWidget);
    expect(find.text('向安康助手咨询您的健康问题'), findsOneWidget);
    expect(find.text('输入想咨询的问题'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom_nav_数据')));
    await tester.pumpAndSettle();
    expect(find.text('健康数据'), findsOneWidget);
    expect(find.text('最新记录'), findsOneWidget);
    expect(find.text('已加载异常'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom_nav_提醒')));
    await tester.pumpAndSettle();
    expect(find.text('今日待办'), findsOneWidget);
    expect(find.text('添加提醒'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom_nav_SOS')));
    await tester.pumpAndSettle();
    expect(find.text('Emergency SOS'), findsOneWidget);
    expect(find.text('安全联系人'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom_nav_我的')));
    await tester.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('个人信息'), findsOneWidget);
    expect(find.text('健康目标'), findsOneWidget);
  });
}
