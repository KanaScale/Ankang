import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/emergency_contact_model.dart';
import 'package:ankang_assistant/models/emergency_event_model.dart';
import 'package:ankang_assistant/models/emergency_dispatch_attempt_model.dart';
import 'package:ankang_assistant/models/local_sos_event_model.dart';
import 'package:ankang_assistant/models/nearby_hospital_model.dart';
import 'package:ankang_assistant/models/sos_device_model.dart';
import 'package:ankang_assistant/models/user_model.dart';
import 'package:ankang_assistant/pages/emergency/contact_page.dart';
import 'package:ankang_assistant/pages/emergency/emergency_page.dart';
import 'package:ankang_assistant/services/emergency_service.dart';
import 'package:ankang_assistant/services/profile_service.dart';
import 'package:ankang_assistant/services/sos_device_service.dart';
import 'package:ankang_assistant/services/sos_preview_builder.dart';
import 'package:ankang_assistant/widgets/pressable_scale.dart';

class _FakeSosDeviceService extends SosDeviceService {
  const _FakeSosDeviceService();

  @override
  Future<SosDeviceReadiness> checkReadiness() async => const SosDeviceReadiness(
        supported: true,
        smsPermission: SosPermissionState.granted,
        callPermission: SosPermissionState.granted,
        locationPermission: 'precise',
        locationServiceEnabled: true,
        defaultSmsSubscriptionId: 1,
        simSlotCount: 1,
        activeSimCount: 1,
      );

  @override
  Future<SosDeviceReadiness> requestPermissions() => checkReadiness();

  @override
  Future<SosLocationResult> resolveLocation({
    Duration timeout = const Duration(seconds: 5),
    Duration cacheMaxAge = const Duration(minutes: 15),
  }) async =>
      const SosLocationResult(
        latitude: 31.2304,
        longitude: 121.4737,
        accuracyMeters: 12,
        source: 'fresh',
      );

  @override
  Future<List<LocalSosEventModel>> getLocalSosEvents({
    required int ownerUserId,
    bool pendingOnly = false,
  }) async =>
      const [];
}

class _FakeProfileService extends ProfileService {
  @override
  Future<BaseResponse<UserModel>> getCurrentUser() async => const BaseResponse(
        code: 200,
        message: 'success',
        success: true,
        data: UserModel(id: 1, username: 'tester', nickname: '王奶奶'),
      );
}

class _FakeEmergencyService extends EmergencyService {
  @override
  Future<BaseResponse<List<NearbyHospitalModel>>> getNearbyHospitals({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) async =>
      const BaseResponse(
        code: 200,
        message: 'success',
        success: true,
        data: [
          NearbyHospitalModel(
            poiId: 'B001',
            name: '市中心医院',
            address: '人民路 100 号',
            distance: '2.3km',
            distanceMeters: 2300,
            source: 'amap',
          ),
          NearbyHospitalModel(
            poiId: 'B002',
            name: '城北医院',
            address: '健康路 20 号',
            distance: '3.1km',
            distanceMeters: 3100,
            source: 'amap',
          ),
          NearbyHospitalModel(
            poiId: 'B003',
            name: '城南医院',
            address: '平安路 8 号',
            distance: '4.2km',
            distanceMeters: 4200,
            source: 'amap',
          ),
        ],
      );

  @override
  Future<BaseResponse<List<EmergencyContactModel>>> getContacts() async =>
      const BaseResponse(
        code: 200,
        message: 'success',
        success: true,
        data: [
          EmergencyContactModel(
            id: 1,
            name: '李女士',
            phone: '13800008888',
            relationship: '家属',
            priority: 1,
            phoneE164: '+8613800008888',
            phoneType: 'mobile',
            smsCapable: true,
          ),
        ],
      );

  @override
  Future<BaseResponse<EmergencyEventModel>> createSosEvent({
    double? latitude,
    double? longitude,
    String? address,
    String? message,
    String? clientEventId,
    DateTime? triggeredAt,
    double? accuracyMeters,
    String? locationSource,
  }) async =>
      BaseResponse(
        code: 200,
        message: 'success',
        success: true,
        data: EmergencyEventModel(
          id: 1,
          createdAt: DateTime(2026, 7, 14, 8),
          status: 'created',
          message: '用户发起紧急求助',
          contactsNotified: 1,
        ),
      );
}

void main() {
  test('parses SOS dispatch contract fields', () {
    final event = EmergencyEventModel.fromJson({
      'id': 7,
      'createdAt': '2026-07-17T08:00:00',
      'clientEventId': 'device-event-7',
      'triggeredAt': '2026-07-17T07:59:58',
      'accuracyMeters': 12.5,
      'locationSource': 'fresh',
      'message': '用户发起紧急求助',
      'contactsNotified': 1,
      'attempts': [
        {
          'attemptId': 'attempt-1',
          'contactId': 3,
          'channel': 'sms',
          'status': 'delivered',
          'occurredAt': '2026-07-17T08:00:05',
        },
      ],
    });

    expect(event.message, '用户发起紧急求助');
    expect(event.clientEventId, 'device-event-7');
    expect(event.accuracyMeters, 12.5);
    expect(event.locationSource, 'fresh');
    expect(event.contactsNotified, 1);
    expect(event.attempts.single.status, 'delivered');
  });

  test('parses emergency contact phone capability fields', () {
    final contact = EmergencyContactModel.fromJson({
      'id': 3,
      'name': '李女士',
      'phone': '13800008888',
      'phoneE164': '+8613800008888',
      'phoneType': 'mobile',
      'smsCapable': true,
    });

    expect(contact.phoneE164, '+8613800008888');
    expect(contact.phoneType, 'mobile');
    expect(contact.smsCapable, isTrue);
  });

  test('builds WGS84 AMap link from Android location result', () {
    final location = SosLocationResult.fromMap({
      'latitude': 31.2304,
      'longitude': 121.4737,
      'accuracyMeters': 12,
      'source': 'fresh',
    });

    expect(location.available, isTrue);
    expect(location.amapUrl, contains('coordinate=wgs84'));
    expect(location.amapUrl, contains('position=121.4737,31.2304'));
  });

  test('recognizes approximate location and missing dual-SIM default', () {
    final readiness = SosDeviceReadiness.fromMap({
      'supported': true,
      'smsPermission': 'granted',
      'callPermission': 'denied',
      'locationPermission': 'approximate',
      'locationServiceEnabled': true,
      'defaultSmsSubscriptionId': null,
      'simSlotCount': 2,
      'activeSimCount': 2,
    });

    expect(readiness.locationPermission, 'approximate');
    expect(readiness.needsDefaultSmsSim, isTrue);
    expect(readiness.callPermission, SosPermissionState.denied);
  });

  test('preview contains nickname time coordinates and map link', () {
    const location = SosLocationResult(
      latitude: 31.2304,
      longitude: 121.4737,
      accuracyMeters: 12,
      source: 'fresh',
    );
    final message = SosPreviewBuilder.build(
      displayName: '王奶奶',
      triggeredAt: DateTime(2026, 7, 20, 15, 30, 5),
      location: location,
    );

    expect(message, contains('王奶奶'));
    expect(message, contains('2026-07-20 15:30:05'));
    expect(message, contains('位置坐标（WGS84）'));
    expect(message, contains('纬度 31.230400'));
    expect(message, contains('经度 121.473700'));
    expect(message, contains('精度约12米'));
    expect(message, contains('coordinate=wgs84'));
  });

  test('parses persisted Android SMS dispatch snapshot', () {
    final attempt = EmergencyDispatchAttemptModel.fromJson({
      'clientEventId': 'test-event',
      'attemptId': 'test-event-s-1',
      'contactId': 1,
      'contactName': '李女士',
      'channel': 'sms',
      'status': 'delivered',
      'occurredAtMillis': 1784532605000,
    });

    expect(attempt.clientEventId, 'test-event');
    expect(attempt.contactName, '李女士');
    expect(attempt.status, 'delivered');
    expect(attempt.occurredAt.millisecondsSinceEpoch, 1784532605000);
  });

  test('parses a pending locally persisted SOS event', () {
    final event = LocalSosEventModel.fromJson({
      'ownerUserId': 7,
      'clientEventId': 'sos-local-1',
      'triggeredAtMillis': 1784532605000,
      'latitude': 31.2304,
      'longitude': 121.4737,
      'accuracyMeters': 12,
      'locationSource': 'cached',
      'message': '测试 SOS',
      'syncPending': true,
      'executionState': 'unknown',
      'syncError': 'network',
      'contactSnapshot': [
        {'id': -1, 'name': '李女士', 'phone': '13800000000'}
      ],
    });

    expect(event.ownerUserId, 7);
    expect(event.clientEventId, 'sos-local-1');
    expect(event.locationSource, 'cached');
    expect(event.syncPending, isTrue);
    expect(event.executionState, SosExecutionState.unknown);
    expect(event.syncError, 'network');
    expect(event.contactSnapshot.single['name'], '李女士');
    expect(event.triggeredAt.millisecondsSinceEpoch, 1784532605000);
  });

  test('parses an AMap nearby hospital without swapping coordinates', () {
    final hospital = NearbyHospitalModel.fromJson({
      'poiId': 'B001',
      'name': '市人民医院',
      'address': '人民路100号',
      'distanceMeters': 1250,
      'distance': '1.3km',
      'phone': '021-12345678',
      'latitude': 31.2304,
      'longitude': 121.4737,
      'category': '医疗保健服务;综合医院',
      'source': 'amap',
    });

    expect(hospital.distanceMeters, 1250);
    expect(hospital.latitude, 31.2304);
    expect(hospital.longitude, 121.4737);
    expect(hospital.source, 'amap');
  });

  testWidgets('loads contacts and describes the real SOS flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EmergencyPage(
          service: _FakeEmergencyService(),
          deviceService: const _FakeSosDeviceService(),
          profileService: _FakeProfileService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('设备就绪检查'), findsNothing);
    expect(find.text('将尝试发送求助短信，并呼叫主要联系人。'), findsOneWidget);
    expect(find.textContaining('确认启动紧急求救'), findsOneWidget);
    expect(find.text('开发调试预览（不发送）'), findsOneWidget);

    final sosButton = find.descendant(
      of: find.byType(PressableScale),
      matching: find.text('SOS'),
    );
    expect(sosButton, findsOneWidget);
    await tester.tap(sosButton);
    await tester.pump();
    expect(find.text('紧急求助'), findsOneWidget);
    expect(
      find.textContaining('将按当前权限和设备状态尝试发送短信'),
      findsOneWidget,
    );
    expect(find.textContaining('不会自动拨打120急救电话'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();

    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('安全联系人'),
      200,
      scrollable: pageScroll,
    );
    expect(find.text('安全联系人'), findsOneWidget);
    expect(find.text('管理'), findsOneWidget);
    expect(find.byIcon(Icons.manage_accounts_rounded), findsNothing);
    expect(find.text('李女士'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('获取附近医院'),
      200,
      scrollable: pageScroll,
    );
    await tester.tap(find.text('获取附近医院'));
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('市中心医院'),
      200,
      scrollable: pageScroll,
    );
    expect(find.text('市中心医院'), findsOneWidget);
    expect(find.text('城北医院'), findsOneWidget);
    expect(find.text('城南医院'), findsNothing);
    expect(find.textContaining('2.3km'), findsOneWidget);
    expect(find.text('附近医院'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('renders the contact CRUD page from EmergencyService data',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ContactPage(service: _FakeEmergencyService())),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('管理您的紧急联系人'), findsOneWidget);
    expect(find.text('李女士'), findsOneWidget);
    expect(find.text('添加联系人'), findsOneWidget);
  });
}
