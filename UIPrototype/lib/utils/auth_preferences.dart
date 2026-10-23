import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthPreferences {
  AuthPreferences._();

  static const _storage = FlutterSecureStorage();
  static const _rememberedUsernameKey = 'auth_remembered_username';
  static const _autoLoginKey = 'auth_auto_login';
  static const _keepSignedInKey = 'auth_keep_signed_in';

  static Future<bool> isKeepSignedInEnabled() async {
    final current = await _storage.read(key: _keepSignedInKey);
    if (current != null) return current == 'true';
    return await _storage.read(key: _autoLoginKey) == 'true';
  }

  static Future<String?> getRememberedUsername() {
    return _storage.read(key: _rememberedUsernameKey);
  }

  static Future<void> saveKeepSignedIn({
    required String username,
    required bool enabled,
  }) async {
    await _storage.write(key: _autoLoginKey, value: enabled.toString());
    await _storage.write(key: _keepSignedInKey, value: enabled.toString());

    if (enabled) {
      await _storage.write(key: _rememberedUsernameKey, value: username);
    } else {
      await _storage.delete(key: _rememberedUsernameKey);
    }
  }

  static Future<void> disableAutoLogin() {
    return setKeepSignedIn(false);
  }

  static Future<void> setKeepSignedIn(bool enabled) async {
    await _storage.write(key: _keepSignedInKey, value: enabled.toString());
    await _storage.write(key: _autoLoginKey, value: enabled.toString());
    if (!enabled) {
      await _storage.delete(key: _rememberedUsernameKey);
    }
  }
}
