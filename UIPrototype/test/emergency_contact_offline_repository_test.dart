import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/emergency_contact_model.dart';
import 'package:ankang_assistant/services/emergency_contact_offline_repository.dart';
import 'package:ankang_assistant/services/emergency_service.dart';

class _FakeEmergencyService extends EmergencyService {
  EmergencyContactModel? savedContact;
  final contacts = <EmergencyContactModel>[];
  var _nextId = 42;
  EmergencyContactModel? createResponseOverride;
  Completer<void>? updateStarted;
  Completer<void>? releaseUpdate;

  @override
  Future<BaseResponse<List<EmergencyContactModel>>> getContacts() async {
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
    savedContact = contact;
    final saved = createResponseOverride ?? contact.copyWith(id: _nextId++);
    contacts.add(saved);
    _normalize(saved.priority == 1 ? saved.id : null);
    return BaseResponse(
      code: 200,
      message: 'success',
      success: true,
      data: contacts.firstWhere((item) => item.id == saved.id),
    );
  }

  @override
  Future<BaseResponse<EmergencyContactModel>> updateContact(
    EmergencyContactModel contact,
  ) async {
    updateStarted?.complete();
    await releaseUpdate?.future;
    updateStarted = null;
    releaseUpdate = null;
    final index = contacts.indexWhere((item) => item.id == contact.id);
    final wasPrimary = contacts[index].priority == 1;
    contacts[index] = wasPrimary && contact.priority == 0
        ? contact.copyWith(priority: contacts.length + 1)
        : contact;
    _normalize(contact.priority == 1 ? contact.id : null);
    return BaseResponse(
      code: 200,
      message: 'success',
      success: true,
      data: contacts.firstWhere((item) => item.id == contact.id),
    );
  }

  void _normalize(int? preferredPrimaryId) {
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
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ankang_assistant/sos_device');
  final states = <int, String>{};
  setUp(() {
    states.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args =
          Map<Object?, Object?>.from(call.arguments as Map? ?? const {});
      final owner = args['ownerUserId'] as int;
      if (call.method == 'loadLocalContactState') return states[owner] ?? '';
      if (call.method == 'saveLocalContactState') {
        states[owner] = args['json'] as String;
        return true;
      }
      return true;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  test('本地联系人按用户隔离并使用负 ID', () async {
    final repo = EmergencyContactOfflineRepository();
    final result = await repo.save(7, const EmergencyContactModel(id: 0, name: '李女士', phone: '13800000000', priority: 1));
    expect(result.data!.id, isNegative);
    expect(await repo.cached(8), isEmpty);
  });

  test('普通联系人同步时将本地排序转换为非主要标记', () async {
    final remote = _FakeEmergencyService();
    final repo = EmergencyContactOfflineRepository(remote: remote);
    final primarySynced = repo.changes.firstWhere(
      (contacts) => contacts.any(
        (contact) =>
            contact.name == '主要联系人' &&
            contact.syncState == ContactSyncState.synced,
      ),
    );

    await repo.save(
      7,
      const EmergencyContactModel(
        id: 0,
        name: '主要联系人',
        phone: '13800000000',
        priority: 1,
      ),
    );
    await primarySynced;
    final regularSynced = repo.changes.firstWhere(
      (contacts) => contacts.any(
        (contact) =>
            contact.name == '普通联系人' &&
            contact.syncState == ContactSyncState.synced,
      ),
    );
    await repo.save(
      7,
      const EmergencyContactModel(
        id: 0,
        name: '普通联系人',
        phone: '13900000000',
        priority: 0,
      ),
    );
    await regularSynced;

    expect(remote.savedContact?.name, '普通联系人');
    expect(remote.savedContact?.priority, 0);
  });

  test('后台同步完成后通知页面最新状态', () async {
    final remote = _FakeEmergencyService();
    final repo = EmergencyContactOfflineRepository(remote: remote);
    final synced = repo.changes.firstWhere(
      (contacts) => contacts.any(
        (contact) =>
            contact.name == '李女士' &&
            contact.syncState == ContactSyncState.synced,
      ),
    );

    await repo.save(
      7,
      const EmergencyContactModel(
        id: 0,
        name: '李女士',
        phone: '13800000000',
        priority: 1,
      ),
    );

    expect((await synced).single.syncState, ContactSyncState.synced);
  });

  test('幂等创建返回旧联系人时继续更新为本地最新内容', () async {
    final remote = _FakeEmergencyService();
    final repo = EmergencyContactOfflineRepository(remote: remote);
    remote.createResponseOverride = const EmergencyContactModel(
      id: 42,
      name: '服务端旧姓名',
      phone: '13800000000',
      priority: 1,
      clientContactId: 'existing-client-id',
    );

    final result = await repo.save(
      7,
      const EmergencyContactModel(
        id: 0,
        name: '本地最新姓名',
        phone: '13800000000',
        priority: 1,
      ),
    );
    await repo.sync(7);

    expect(result.data!.name, '本地最新姓名');
    expect(
      remote.contacts.single.name,
      '本地最新姓名',
    );
    expect(
      (await repo.cached(7))!.single.name,
      '本地最新姓名',
    );
  });

  test('切换和取消主要联系人时本地排序遵循本次编辑意图', () async {
    final remote = _FakeEmergencyService();
    final repo = EmergencyContactOfflineRepository(remote: remote);

    final firstSynced = repo.changes.firstWhere(
      (contacts) => contacts.any(
        (contact) =>
            contact.name == '甲联系人' &&
            contact.syncState == ContactSyncState.synced,
      ),
    );
    await repo.save(
      7,
      const EmergencyContactModel(
        id: 0,
        name: '甲联系人',
        phone: '13800000001',
        priority: 1,
      ),
    );
    await firstSynced;
    final secondSynced = repo.changes.firstWhere(
      (contacts) => contacts.any(
        (contact) =>
            contact.name == '乙联系人' &&
            contact.syncState == ContactSyncState.synced,
      ),
    );
    await repo.save(
      7,
      const EmergencyContactModel(
        id: 0,
        name: '乙联系人',
        phone: '13800000002',
        priority: 0,
      ),
    );
    await secondSynced;

    var contacts = (await repo.cached(7))!;
    final secondary =
        contacts.firstWhere((contact) => contact.name == '乙联系人');
    await repo.save(7, secondary.copyWith(priority: 1));
    contacts = (await repo.cached(7))!;
    expect(
      contacts.firstWhere((contact) => contact.name == '乙联系人').priority,
      1,
    );
    expect(
      contacts.firstWhere((contact) => contact.name == '甲联系人').priority,
      2,
    );

    final currentPrimary =
        contacts.firstWhere((contact) => contact.name == '乙联系人');
    await repo.save(7, currentPrimary.copyWith(priority: 0));
    contacts = (await repo.cached(7))!;
    expect(
      contacts.firstWhere((contact) => contact.name == '甲联系人').priority,
      1,
    );
    expect(
      contacts.firstWhere((contact) => contact.name == '乙联系人').priority,
      2,
    );
  });

  test('弱网同步期间跨页面连续编辑联系人不会回滚最新状态', () async {
    final remote = _FakeEmergencyService();
    final firstRepo = EmergencyContactOfflineRepository(remote: remote);
    final secondRepo = EmergencyContactOfflineRepository(remote: remote);

    final firstSynced = firstRepo.changes.firstWhere(
      (contacts) => contacts.any(
        (contact) =>
            contact.name == '甲联系人' &&
            contact.syncState == ContactSyncState.synced,
      ),
    );
    await firstRepo.save(
      7,
      const EmergencyContactModel(
        id: 0,
        name: '甲联系人',
        phone: '13800000001',
        priority: 1,
      ),
    );
    await firstSynced;
    final secondSynced = firstRepo.changes.firstWhere(
      (contacts) => contacts.any(
        (contact) =>
            contact.name == '乙联系人' &&
            contact.syncState == ContactSyncState.synced,
      ),
    );
    await firstRepo.save(
      7,
      const EmergencyContactModel(
        id: 0,
        name: '乙联系人',
        phone: '13800000002',
        priority: 0,
      ),
    );
    await secondSynced;

    var contacts = (await firstRepo.cached(7))!;
    final secondary =
        contacts.firstWhere((contact) => contact.name == '乙联系人');
    remote.updateStarted = Completer<void>();
    remote.releaseUpdate = Completer<void>();
    await firstRepo.save(7, secondary.copyWith(priority: 1));
    await remote.updateStarted!.future;

    final latest = await secondRepo
        .save(
          7,
          secondary.copyWith(name: '乙联系人最新', priority: 1),
        )
        .timeout(const Duration(seconds: 1));
    expect(latest.data!.name, '乙联系人最新');
    expect(
      (await secondRepo.cached(7))!
          .firstWhere((contact) => contact.priority == 1)
          .name,
      '乙联系人最新',
    );

    remote.releaseUpdate!.complete();
    await secondRepo.sync(7);
    contacts = (await secondRepo.cached(7))!;
    expect(
      contacts.firstWhere((contact) => contact.priority == 1).name,
      '乙联系人最新',
    );
    expect(
      remote.contacts.firstWhere((contact) => contact.priority == 1).name,
      '乙联系人最新',
    );
  });
}
