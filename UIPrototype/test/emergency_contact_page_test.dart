import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/emergency_contact_model.dart';
import 'package:ankang_assistant/pages/emergency/contact_page.dart';
import 'package:ankang_assistant/services/emergency_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 联系人页面测试替身：模拟 Service CRUD 和服务端 priority 重排，
/// 使 Widget 测试不依赖网络、认证或数据库。
class _FakeEmergencyService extends EmergencyService {
  _FakeEmergencyService({
    List<EmergencyContactModel>? initialContacts,
    this.failRefreshAfterUpdate = false,
  }) : contacts = List.of(initialContacts ?? _defaultContacts);

  // 默认数据覆盖主要联系人和普通联系人两种展示状态。
  static const _defaultContacts = [
    EmergencyContactModel(
      id: 1,
      name: '李女士',
      phone: '13800008889',
      relationship: '家属',
      priority: 1,
    ),
    EmergencyContactModel(
      id: 2,
      name: '社区医生',
      phone: '13900008888',
      relationship: '医生',
      priority: 2,
    ),
  ];

  // 测试可直接断言此列表，确认页面操作已调用正确的 Service 方法。
  final List<EmergencyContactModel> contacts;
  final bool failRefreshAfterUpdate;
  int _nextId = 1000;
  bool _updated = false;

  @override
  Future<BaseResponse<List<EmergencyContactModel>>> getContacts() async {
    if (failRefreshAfterUpdate && _updated) {
      throw Exception('refresh failed');
    }
    return BaseResponse(
      code: 200,
      message: 'success',
      success: true,
      data: List.unmodifiable(contacts),
    );
  }

  @override
  Future<BaseResponse<EmergencyContactModel>> saveContact(
    EmergencyContactModel contact,
  ) async {
    final saved = contact.copyWith(id: _nextId++);
    contacts.add(saved);
    _normalize(preferredPrimaryId: saved.priority == 1 ? saved.id : null);
    return _success(contacts.firstWhere((item) => item.id == saved.id));
  }

  @override
  Future<BaseResponse<EmergencyContactModel>> updateContact(
    EmergencyContactModel contact,
  ) async {
    final index = contacts.indexWhere((item) => item.id == contact.id);
    final wasPrimary = contacts[index].priority == 1;
    contacts[index] = wasPrimary && contact.priority == 0
        ? contact.copyWith(priority: contacts.length + 1)
        : contact;
    _normalize(preferredPrimaryId: contact.priority == 1 ? contact.id : null);
    _updated = true;
    return _success(contacts.firstWhere((item) => item.id == contact.id));
  }

  @override
  Future<BaseResponse<void>> deleteContact(int id) async {
    contacts.removeWhere((item) => item.id == id);
    _normalize();
    return const BaseResponse(
      code: 200,
      message: 'success',
      success: true,
    );
  }

  BaseResponse<EmergencyContactModel> _success(
    EmergencyContactModel contact,
  ) {
    return BaseResponse(
      code: 200,
      message: 'success',
      success: true,
      data: contact,
    );
  }

  /// 模拟后端约定：priority=1 唯一，其余联系人连续编号。
  void _normalize({int? preferredPrimaryId}) {
    if (contacts.isEmpty) return;
    contacts.sort((a, b) {
      if (a.id == preferredPrimaryId) return -1;
      if (b.id == preferredPrimaryId) return 1;
      return a.priority.compareTo(b.priority);
    });
    for (var index = 0; index < contacts.length; index++) {
      contacts[index] = contacts[index].copyWith(priority: index + 1);
    }
  }
}

void main() {
  // 每个用例注入独立 Fake Service，避免测试之间共享状态。
  Widget buildPage(_FakeEmergencyService service) {
    return MaterialApp(home: ContactPage(service: service));
  }

  // 等待页面首次异步加载以及相关过渡动画完成。
  Future<void> loadPage(
    WidgetTester tester,
    _FakeEmergencyService service,
  ) async {
    await tester.pumpWidget(buildPage(service));
    await tester.pumpAndSettle();
  }

  testWidgets('展示联系人、主要联系人和真实能力说明', (tester) async {
    await loadPage(tester, _FakeEmergencyService());

    expect(find.text('李女士'), findsOneWidget);
    expect(find.text('社区医生'), findsOneWidget);
    expect(find.text('主要联系人'), findsOneWidget);
    expect(find.textContaining('会尝试向可接收短信的联系人发送求助短信'), findsOneWidget);
    expect(find.textContaining('并呼叫主要联系人'), findsOneWidget);
  });

  testWidgets('添加联系人按钮使用无阴影圆角矩形', (tester) async {
    await loadPage(tester, _FakeEmergencyService());

    final button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.shape, isA<RoundedRectangleBorder>());
    expect(button.elevation, 0);
    expect(button.highlightElevation, 0);
    expect(find.text('添加联系人'), findsOneWidget);
  });

  testWidgets('主要联系人设置区域使用无阴影扁平容器', (tester) async {
    await loadPage(tester, _FakeEmergencyService());
    await tester.tap(find.byTooltip('编辑联系人').first);
    await tester.pumpAndSettle();

    expect(find.text('SOS 启动后优先呼叫此联系人'), findsOneWidget);

    final tile = find.byType(SwitchListTile);
    final material = tester.widget<Material>(
      find.ancestor(of: tile, matching: find.byType(Material)).first,
    );
    expect(material.elevation, 0);
    expect(material.shadowColor, Colors.transparent);
  });

  testWidgets('空状态提供添加第一位联系人入口', (tester) async {
    await loadPage(tester, _FakeEmergencyService(initialContacts: const []));

    expect(find.text('还没有紧急联系人'), findsOneWidget);
    expect(find.text('添加后可在紧急求救页查看，并用于 SOS 联系流程。'), findsOneWidget);
    expect(find.text('添加第一位联系人'), findsOneWidget);
  });

  testWidgets('新增联系人时校验姓名和电话', (tester) async {
    final service = _FakeEmergencyService(initialContacts: const []);
    await loadPage(tester, service);
    await tester.tap(find.text('添加第一位联系人'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('请输入联系人姓名'), findsOneWidget);
    expect(find.text('请输入手机号'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '王先生');
    await tester.enterText(find.byType(TextFormField).at(1), '家属');
    await tester.enterText(find.byType(TextFormField).at(2), '13900001234');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('王先生'), findsOneWidget);
    expect(service.contacts.single.priority, 1);
  });

  testWidgets('拒绝格式错误的电话号码', (tester) async {
    final service = _FakeEmergencyService(initialContacts: const []);
    await loadPage(tester, service);
    await tester.tap(find.text('添加第一位联系人'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '王先生');
    await tester.enterText(find.byType(TextFormField).at(2), 'abc-123');
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入正确的手机号'), findsOneWidget);
    expect(service.contacts, isEmpty);
  });

  testWidgets('拒绝非 11 位大陆手机号', (tester) async {
    final service = _FakeEmergencyService(initialContacts: const []);
    await loadPage(tester, service);
    await tester.tap(find.text('添加第一位联系人'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '王先生');
    await tester.enterText(find.byType(TextFormField).at(2), '12345678');
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入正确的手机号'), findsOneWidget);
    expect(service.contacts, isEmpty);
  });

  testWidgets('新增重复手机号时显示明确提醒且不提交', (tester) async {
    final service = _FakeEmergencyService();
    await loadPage(tester, service);
    await tester.tap(find.text('添加联系人'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '新联系人');
    await tester.enterText(find.byType(TextFormField).at(2), '13800008889');
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('该手机号已存在，请勿重复添加'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(service.contacts, hasLength(2));
  });

  testWidgets('编辑后可以切换唯一主要联系人', (tester) async {
    final service = _FakeEmergencyService();
    await loadPage(tester, service);

    await tester.tap(find.byTooltip('编辑联系人').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(service.contacts.first.name, '社区医生');
    expect(service.contacts.first.priority, 1);
    expect(
      service.contacts.where((contact) => contact.priority == 1),
      hasLength(1),
    );
    expect(find.text('主要联系人'), findsOneWidget);
  });

  testWidgets('取消当前主要联系人后下一位自动递补', (tester) async {
    final service = _FakeEmergencyService();
    await loadPage(tester, service);

    await tester.tap(find.byTooltip('编辑联系人').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(service.contacts.first.name, '社区医生');
    expect(service.contacts.first.priority, 1);
    expect(service.contacts.last.name, '李女士');
    expect(service.contacts.last.priority, 2);
    expect(find.text('主要联系人'), findsOneWidget);
  });

  testWidgets('更新成功但列表刷新失败时立即重绘且不提示操作失败', (tester) async {
    final service = _FakeEmergencyService(failRefreshAfterUpdate: true);
    await loadPage(tester, service);

    await tester.tap(find.byTooltip('编辑联系人').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(service.contacts.first.name, '社区医生');
    expect(find.text('主要联系人'), findsOneWidget);
    expect(find.text('联系人已更新'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsNothing);
  });

  testWidgets('编辑联系人未修改内容直接保存不会触发生命周期断言', (tester) async {
    final service = _FakeEmergencyService();
    await loadPage(tester, service);

    await tester.tap(find.byTooltip('编辑联系人').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(service.contacts.first.name, '李女士');
    expect(service.contacts.first.phone, '13800008889');
  });

  testWidgets('取消删除不会改变联系人', (tester) async {
    final service = _FakeEmergencyService();
    await loadPage(tester, service);

    await tester.tap(find.byTooltip('删除联系人').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(service.contacts, hasLength(2));
  });

  testWidgets('删除主要联系人后下一位自动递补', (tester) async {
    final service = _FakeEmergencyService(
      initialContacts: const [
        EmergencyContactModel(
          id: 1,
          name: '甲联系人',
          phone: '13800000001',
          priority: 1,
        ),
        EmergencyContactModel(
          id: 2,
          name: '乙联系人',
          phone: '13800000002',
          priority: 2,
        ),
      ],
    );
    await loadPage(tester, service);

    await tester.tap(find.byTooltip('删除联系人').first);
    await tester.pumpAndSettle();
    expect(find.text('删除联系人'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(service.contacts.single.name, '乙联系人');
    expect(service.contacts.single.priority, 1);
  });
}
