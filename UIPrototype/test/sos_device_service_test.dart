import 'package:ankang_assistant/models/emergency_contact_model.dart';
import 'package:ankang_assistant/services/sos_device_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ankang_assistant/sos_device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  MethodCall? capturedCall;

  setUp(() {
    capturedCall = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return <Object?>[];
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('SOS派送不把离线联系人的负ID写入持久化载荷', () async {
    await const SosDeviceService().dispatchSos(
      ownerUserId: 7,
      clientEventId: 'event-1',
      message: '需要帮助',
      contacts: const [
        EmergencyContactModel(
          id: -123,
          name: '离线联系人',
          phone: '13800000000',
          priority: 1,
        ),
      ],
    );

    final arguments =
        Map<Object?, Object?>.from(capturedCall!.arguments as Map);
    final contacts = arguments['contacts'] as List<Object?>;
    final payload = Map<Object?, Object?>.from(contacts.single as Map);
    expect(payload['contactId'], isNull);
    expect(payload['contactName'], '离线联系人');
    expect(payload['smsAttemptId'], isNotEmpty);
    expect(payload['callAttemptId'], isNotEmpty);
  });
}
