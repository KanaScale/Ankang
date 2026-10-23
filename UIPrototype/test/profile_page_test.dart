import 'package:ankang_assistant/routes/app_routes.dart';
import 'package:ankang_assistant/models/user_model.dart';
import 'package:ankang_assistant/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AuthService.cacheCurrentUser(
      const UserModel(id: 1, username: 'zhangsan', nickname: '张三'),
    );
  });

  tearDown(() {
    AuthService.cacheCurrentUser(null);
  });

  testWidgets('profile page shows user dashboard cards', (tester) async {
    await _pumpProfilePage(tester);

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('用户信息'), findsOneWidget);
    expect(find.text('健康档案'), findsWidgets);
    expect(find.text('健康目标'), findsOneWidget);
  });

  testWidgets('profile modules navigate to detail pages', (tester) async {
    await _pumpProfilePage(tester);

    await _openModule(tester, '用户信息', '账户资料');
    await _openModule(tester, '健康档案', '健康档案');
    await _openModule(tester, '健康目标', '每日步数');
    await _openModule(tester, '紧急联系人', '管理您的紧急联系人');
    await _openModule(tester, '设备同步', '连接状态');
    await _openModule(tester, '设置', '字号大小');
  });

  testWidgets('profile detail pages support editing', (tester) async {
    await _pumpProfilePage(tester);

    await tester.tap(find.text('用户信息').first);
    await tester.pumpAndSettle();
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('身高'), findsNothing);
    expect(find.text('体重'), findsNothing);
    expect(find.text('健康档案'), findsNothing);
    expect(find.text('修改密码'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('修改密码'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('修改密码'));
    await tester.pumpAndSettle();
    expect(find.text('新密码'), findsOneWidget);
    expect(find.text('确认新密码'), findsOneWidget);
  });

  testWidgets('profile settings render', (tester) async {
    await _pumpProfilePage(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    expect(find.text('字号大小'), findsOneWidget);
    expect(find.text('健康提醒通知'), findsOneWidget);
    expect(find.text('大按钮模式'), findsOneWidget);
    expect(find.text('简洁模式'), findsOneWidget);
  });

  testWidgets('profile logout returns to login', (tester) async {
    await _pumpProfilePage(tester);

    await tester.ensureVisible(find.byTooltip('退出登录'));
    await tester.tap(find.byTooltip('退出登录'));
    await tester.pumpAndSettle();
    expect(find.text('守护您的每一天健康'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}

Future<void> _pumpProfilePage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      routes: AppRoutes.routes,
      initialRoute: AppRoutes.profile,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openModule(
  WidgetTester tester,
  String title,
  String expectedText,
) async {
  await tester.scrollUntilVisible(
    find.text(title),
    260,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();

  expect(find.text(expectedText), findsWidgets);

  await tester.pageBack();
  await tester.pumpAndSettle();
}
