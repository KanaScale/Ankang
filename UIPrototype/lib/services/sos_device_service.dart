import 'package:flutter/services.dart';

import '../models/emergency_contact_model.dart';
import '../models/emergency_dispatch_attempt_model.dart';
import '../models/local_sos_event_model.dart';
import '../models/sos_device_model.dart';

class SosDeviceService {
  const SosDeviceService();

  static const MethodChannel _channel =
      MethodChannel('ankang_assistant/sos_device');

  Future<SosDeviceReadiness> checkReadiness() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'checkReadiness',
      );
      return result == null
          ? const SosDeviceReadiness.unsupported()
          : SosDeviceReadiness.fromMap(result);
    } on MissingPluginException {
      return const SosDeviceReadiness.unsupported();
    } on PlatformException {
      return const SosDeviceReadiness.unsupported();
    }
  }

  Future<SosDeviceReadiness> requestPermissions() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'requestPermissions',
      );
      return result == null
          ? const SosDeviceReadiness.unsupported()
          : SosDeviceReadiness.fromMap(result);
    } on MissingPluginException {
      return const SosDeviceReadiness.unsupported();
    } on PlatformException {
      return checkReadiness();
    }
  }

  Future<SosLocationResult> resolveLocation({
    Duration timeout = const Duration(seconds: 5),
    Duration cacheMaxAge = const Duration(minutes: 15),
  }) async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'resolveLocation',
        {
          'timeoutMillis': timeout.inMilliseconds,
          'cacheMaxAgeMillis': cacheMaxAge.inMilliseconds,
        },
      );
      return SosLocationResult.fromMap(result ?? const {});
    } on MissingPluginException {
      return const SosLocationResult(
        source: 'unavailable',
        errorCode: 'platform_unsupported',
      );
    } on PlatformException catch (error) {
      return SosLocationResult(
        source: 'unavailable',
        errorCode: error.code,
      );
    }
  }

  Future<bool> openSmsSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openSmsSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<List<EmergencyDispatchAttemptModel>> dispatchSos({
    required int ownerUserId,
    required String clientEventId,
    required String message,
    required List<EmergencyContactModel> contacts,
    LocalSosEventModel? event,
  }) async {
    final payload = contacts
        .map(
          (contact) => {
            'contactId': _persistedContactId(contact),
            'contactName': contact.name,
            'phone': contact.phoneE164 ?? contact.phone,
            'smsCapable': contact.smsCapable,
            'priority': contact.priority,
            'smsAttemptId': _attemptId(clientEventId, 'sms', contact.id),
            'callAttemptId': _attemptId(clientEventId, 'call', contact.id),
          },
        )
        .toList();
    final result = await _channel.invokeListMethod<Object?>(
      'dispatchSos',
      {
        'ownerUserId': ownerUserId,
        'clientEventId': clientEventId,
        'message': message,
        'contacts': payload,
        'event': event?.toPlatformMap(),
      },
    );
    return _parseAttempts(result);
  }

  Future<List<EmergencyDispatchAttemptModel>> getDispatchSnapshot(
    int ownerUserId,
    String clientEventId,
  ) async {
    final result = await _channel.invokeListMethod<Object?>(
      'getDispatchSnapshot',
      {
        'ownerUserId': ownerUserId,
        'clientEventId': clientEventId,
      },
    );
    return _parseAttempts(result);
  }

  Future<List<EmergencyDispatchAttemptModel>> callEmergencyNumber({
    required int ownerUserId,
    required String clientEventId,
    required EmergencyContactModel contact,
  }) async {
    return callNumber(
      ownerUserId: ownerUserId,
      clientEventId: clientEventId,
      attemptId: _attemptId(clientEventId, 'call', contact.id),
      phone: contact.phoneE164 ?? contact.phone,
      contactId: _persistedContactId(contact),
      contactName: contact.name,
    );
  }

  Future<List<EmergencyDispatchAttemptModel>> callNumber({
    required int ownerUserId,
    required String clientEventId,
    required String attemptId,
    required String phone,
    int? contactId,
    String? contactName,
  }) async {
    final result = await _channel.invokeListMethod<Object?>(
      'callEmergencyNumber',
      {
        'ownerUserId': ownerUserId,
        'clientEventId': clientEventId,
        'attemptId': attemptId,
        'contactId': contactId,
        'contactName': contactName,
        'phone': phone,
      },
    );
    return _parseAttempts(result);
  }

  Future<void> saveLocalSosEvent(LocalSosEventModel event) async {
    await _channel.invokeMethod<bool>(
      'saveLocalSosEvent',
      {'event': event.toPlatformMap()},
    );
  }

  Future<List<LocalSosEventModel>> getLocalSosEvents({
    required int ownerUserId,
    bool pendingOnly = false,
  }) async {
    final result = await _channel.invokeListMethod<Object?>(
      'getLocalSosEvents',
      {
        'ownerUserId': ownerUserId,
        'pendingOnly': pendingOnly,
      },
    );
    return result
            ?.map(LocalSosEventModel.fromJson)
            .where(
              (event) =>
                  event.ownerUserId == ownerUserId &&
                  event.clientEventId.isNotEmpty,
            )
            .toList(growable: false) ??
        const [];
  }

  Future<void> markLocalSosEventSynced(
    int ownerUserId,
    String clientEventId,
  ) async {
    await _channel.invokeMethod<bool>(
      'markLocalSosEventSynced',
      {
        'ownerUserId': ownerUserId,
        'clientEventId': clientEventId,
      },
    );
  }

  Future<void> deleteLocalSosEvent(
    int ownerUserId,
    String clientEventId,
  ) async {
    await _channel.invokeMethod<bool>(
      'deleteLocalSosEvent',
      {
        'ownerUserId': ownerUserId,
        'clientEventId': clientEventId,
      },
    );
  }

  List<EmergencyDispatchAttemptModel> _parseAttempts(List<Object?>? source) {
    return source
            ?.map(EmergencyDispatchAttemptModel.fromJson)
            .toList(growable: false) ??
        const [];
  }

  String _attemptId(String clientEventId, String channel, int contactId) {
    final eventPart = clientEventId.length <= 20
        ? clientEventId
        : clientEventId.substring(clientEventId.length - 20);
    final channelPart = channel == 'sms' ? 's' : 'c';
    return '$eventPart-$channelPart-${contactId.toRadixString(36)}';
  }

  int? _persistedContactId(EmergencyContactModel contact) {
    return contact.id > 0 ? contact.id : null;
  }
}
