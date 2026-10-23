import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum CareMode {
  patient,
  caregiver,
}

extension CareModeLabel on CareMode {
  String get storageValue => switch (this) {
        CareMode.patient => 'patient',
        CareMode.caregiver => 'caregiver',
      };

  String get label => switch (this) {
        CareMode.patient => '病人版',
        CareMode.caregiver => '家属版',
      };

  static CareMode fromStorageValue(String? value) {
    return switch (value) {
      'caregiver' => CareMode.caregiver,
      _ => CareMode.patient,
    };
  }
}

class CareModeService {
  CareModeService._();

  static const _storage = FlutterSecureStorage();
  static const _keyPrefix = 'care_mode_user_';

  static final ValueNotifier<CareMode> mode =
      ValueNotifier<CareMode>(CareMode.patient);
  static final ValueNotifier<bool> selectionKnown = ValueNotifier<bool>(false);

  static int? _currentUserId;

  static bool get isCaregiver => mode.value == CareMode.caregiver;

  static Future<void> loadForUser(int? userId) async {
    _currentUserId = userId != null && userId > 0 ? userId : null;
    if (_currentUserId == null) {
      mode.value = CareMode.patient;
      selectionKnown.value = false;
      return;
    }

    final raw = await _storage.read(key: _storageKey(_currentUserId!));
    if (raw == null || raw.isEmpty) {
      mode.value = CareMode.patient;
      selectionKnown.value = false;
      return;
    }
    mode.value = CareModeLabel.fromStorageValue(raw);
    selectionKnown.value = true;
  }

  static Future<void> selectMode(CareMode selectedMode) async {
    mode.value = selectedMode;
    selectionKnown.value = true;
    final userId = _currentUserId;
    if (userId != null) {
      await _storage.write(
        key: _storageKey(userId),
        value: selectedMode.storageValue,
      );
    }
  }

  static void clearRuntime() {
    _currentUserId = null;
    mode.value = CareMode.patient;
    selectionKnown.value = false;
  }

  static String _storageKey(int userId) => '$_keyPrefix$userId';
}
