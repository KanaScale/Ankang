import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/reminder_model.dart';
import 'package:ankang_assistant/services/api_client.dart';
import 'package:ankang_assistant/services/reminder_offline_repository.dart';
import 'package:ankang_assistant/services/reminder_service.dart';

class _FakeRemoteReminderService extends ReminderService {
  bool online = false;
  int createCalls = 0;
  int deleteCalls = 0;
  int updateCalls = 0;
  ReminderModel? lastCreated;
  ReminderModel? lastUpdated;
  ReminderModel? createResponseOverride;
  Completer<void>? updateStarted;
  Completer<void>? releaseUpdate;

  @override
  Future<BaseResponse<ReminderModel>> saveReminder(
    ReminderModel reminder,
  ) async {
    if (!online) throw const ApiException('网络连接失败');
    createCalls++;
    lastCreated = reminder;
    return BaseResponse<ReminderModel>(
      code: 200,
      message: 'success',
      success: true,
      data: createResponseOverride ?? reminder.copyWith(id: 99),
    );
  }

  @override
  Future<BaseResponse<ReminderModel>> updateReminder(
    ReminderModel reminder,
  ) async {
    if (!online) throw const ApiException('网络连接失败');
    updateCalls++;
    lastUpdated = reminder;
    updateStarted?.complete();
    await releaseUpdate?.future;
    updateStarted = null;
    releaseUpdate = null;
    return BaseResponse<ReminderModel>(
      code: 200,
      message: 'success',
      success: true,
      data: reminder,
    );
  }

  @override
  Future<BaseResponse<void>> deleteReminder(int id) async {
    if (!online) throw const ApiException('网络连接失败');
    deleteCalls++;
    return const BaseResponse<void>(
      code: 200,
      message: 'success',
      success: true,
    );
  }
}

ReminderModel _draft({String title = '离线服药'}) => ReminderModel(
      id: 0,
      title: title,
      type: ReminderType.medicine,
      remindAt: DateTime.now().add(const Duration(hours: 1)),
      repeatType: ReminderRepeatType.once,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ankang_assistant/reminder_alarm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final states = <int, String>{};
  final alarmCalls = <MethodCall>[];

  setUp(() {
    states.clear();
    alarmCalls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments =
          Map<Object?, Object?>.from(call.arguments as Map? ?? const {});
      final owner = arguments['ownerUserId'] as int? ?? 0;
      switch (call.method) {
        case 'loadLocalReminderState':
          return states[owner] ?? '';
        case 'saveLocalReminderState':
          states[owner] = arguments['json'] as String;
          return true;
        case 'schedule':
        case 'cancel':
          alarmCalls.add(call);
          return true;
      }
      return true;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('离线新增使用负 ID 并立即注册本地闹钟', () async {
    final remote = _FakeRemoteReminderService();
    final repository = ReminderOfflineRepository(remote: remote);

    final response = await repository.create(7, _draft());

    expect(response.success, isTrue);
    expect(response.data!.id, isNegative);
    expect(response.data!.syncState, ReminderSyncState.pending);
    expect(
      alarmCalls.any(
        (call) =>
            call.method == 'schedule' &&
            call.arguments['reminderId'] == response.data!.id,
      ),
      isTrue,
    );
  });

  test('联网同步后用服务端 ID 替换本地 ID 和闹钟', () async {
    final remote = _FakeRemoteReminderService();
    final repository = ReminderOfflineRepository(remote: remote);
    final created = (await repository.create(7, _draft())).data!;
    remote.online = true;

    await repository.sync(7);
    final cached = await repository.getCachedReminders(7);

    expect(remote.createCalls, 1);
    expect(cached, hasLength(1));
    expect(cached!.single.id, 99);
    expect(cached.single.syncState, ReminderSyncState.synced);
    expect(
      alarmCalls.any(
        (call) =>
            call.method == 'cancel' &&
            call.arguments['reminderId'] == created.id,
      ),
      isTrue,
    );
    expect(
      alarmCalls.any(
        (call) =>
            call.method == 'schedule' && call.arguments['reminderId'] == 99,
      ),
      isTrue,
    );
  });

  test('未同步新增的连续编辑会压缩为一次最新创建', () async {
    final remote = _FakeRemoteReminderService();
    final repository = ReminderOfflineRepository(remote: remote);
    final created = (await repository.create(7, _draft())).data!;

    await repository.update(
      7,
      created.copyWith(title: '最新离线标题'),
    );
    remote.online = true;
    await repository.sync(7);

    expect(remote.createCalls, 1);
    expect(remote.lastCreated?.title, '最新离线标题');
  });

  test('幂等创建返回旧服务端内容时继续更新为本地最新版本', () async {
    final remote = _FakeRemoteReminderService();
    final repository = ReminderOfflineRepository(remote: remote);
    final created = (await repository.create(7, _draft())).data!;
    await repository.update(
      7,
      created.copyWith(title: '离线修改后的标题'),
    );
    remote
      ..online = true
      ..createResponseOverride = _draft(title: '服务端旧标题').copyWith(id: 99);

    await repository.sync(7);

    expect(remote.updateCalls, 1);
    expect(remote.lastUpdated?.title, '离线修改后的标题');
    expect(
      (await repository.getCachedReminders(7))!.single.title,
      '离线修改后的标题',
    );
  });

  test('删除未同步新增不会向服务端提交删除', () async {
    final remote = _FakeRemoteReminderService();
    final repository = ReminderOfflineRepository(remote: remote);
    final created = (await repository.create(7, _draft())).data!;

    await repository.delete(7, created.id);
    remote.online = true;
    await repository.sync(7);

    expect(await repository.getCachedReminders(7), isEmpty);
    expect(remote.deleteCalls, 0);
  });

  test('本地提醒按登录用户隔离', () async {
    final repository = ReminderOfflineRepository(
      remote: _FakeRemoteReminderService(),
    );

    await repository.create(7, _draft(title: '用户七提醒'));

    expect(await repository.getCachedReminders(7), hasLength(1));
    expect(await repository.getCachedReminders(8), isEmpty);
  });

  test('弱网同步期间跨页面连续编辑不会阻塞或覆盖最新内容', () async {
    final remote = _FakeRemoteReminderService();
    final firstRepository = ReminderOfflineRepository(remote: remote);
    final secondRepository = ReminderOfflineRepository(remote: remote);
    final created = (await firstRepository.create(7, _draft())).data!;
    remote.online = true;
    await firstRepository.sync(7);
    final synced = (await firstRepository.getCachedReminders(7))!.single;

    remote.updateStarted = Completer<void>();
    remote.releaseUpdate = Completer<void>();
    await firstRepository.update(
      7,
      synced.copyWith(title: '第一次编辑'),
    );
    await remote.updateStarted!.future;

    final latest = await secondRepository
        .update(7, synced.copyWith(title: '弱网下的最新编辑'))
        .timeout(const Duration(seconds: 1));
    expect(latest.data!.title, '弱网下的最新编辑');
    expect(
      (await secondRepository.getCachedReminders(7))!.single.title,
      '弱网下的最新编辑',
    );

    remote.releaseUpdate!.complete();
    await secondRepository.sync(7);
    final finalCached =
        (await secondRepository.getCachedReminders(7))!.single;
    expect(finalCached.title, '弱网下的最新编辑');
    expect(finalCached.id, 99);
    expect(finalCached.syncState, ReminderSyncState.synced);
    expect(remote.lastUpdated?.title, '弱网下的最新编辑');
    expect(created.id, isNegative);
  });
}
