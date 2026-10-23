import 'package:flutter/services.dart';

class ReminderLocalStoreService {
  const ReminderLocalStoreService();

  static const MethodChannel _channel =
      MethodChannel('ankang_assistant/reminder_alarm');

  Future<String?> load(int ownerUserId) async {
    try {
      return _channel.invokeMethod<String>(
        'loadLocalReminderState',
        {'ownerUserId': ownerUserId},
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> save(int ownerUserId, String json) async {
    try {
      return await _channel.invokeMethod<bool>(
            'saveLocalReminderState',
            {'ownerUserId': ownerUserId, 'json': json},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
