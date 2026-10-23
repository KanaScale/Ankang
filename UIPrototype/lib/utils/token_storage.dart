import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _accessTokenExpiresAtKey = 'auth_access_token_expires_at';
  static const _refreshTokenExpiresAtKey = 'auth_refresh_token_expires_at';
  static const _userKey = 'offline_user';

  static Future<void> saveToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() {
    return _storage.read(key: _tokenKey);
  }

  static Future<void> clearToken() {
    return _storage.delete(key: _tokenKey);
  }

  static Future<void> saveAuthSession({
    required String accessToken,
    required int accessTokenExpiresInSeconds,
    String? refreshToken,
    DateTime? refreshTokenExpiresAt,
  }) async {
    final now = DateTime.now();
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(
      key: _accessTokenExpiresAtKey,
      value: now
          .add(Duration(seconds: accessTokenExpiresInSeconds))
          .toUtc()
          .toIso8601String(),
    );
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        refreshTokenExpiresAt == null) {
      await clearRefreshToken();
      return;
    }
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(
      key: _refreshTokenExpiresAtKey,
      value: refreshTokenExpiresAt.toUtc().toIso8601String(),
    );
  }

  static Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  static Future<DateTime?> getAccessTokenExpiresAt() async {
    final raw = await _storage.read(key: _accessTokenExpiresAtKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  static Future<bool> hasUsableAccessToken({DateTime? now}) async {
    final token = await getToken();
    final expiresAt = await getAccessTokenExpiresAt();
    return token != null &&
        token.isNotEmpty &&
        expiresAt != null &&
        expiresAt.isAfter(now ?? DateTime.now());
  }

  static Future<DateTime?> getRefreshTokenExpiresAt() async {
    final raw = await _storage.read(key: _refreshTokenExpiresAtKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  static Future<bool> hasUsableRefreshToken({DateTime? now}) async {
    final token = await getRefreshToken();
    final expiresAt = await getRefreshTokenExpiresAt();
    return token != null &&
        token.isNotEmpty &&
        expiresAt != null &&
        expiresAt.isAfter(now ?? DateTime.now());
  }

  static Future<void> clearRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _refreshTokenExpiresAtKey);
  }

  static Future<void> clearAuthSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _accessTokenExpiresAtKey);
    await clearRefreshToken();
  }

  static Future<void> saveOfflineUser(String json) =>
      _storage.write(key: _userKey, value: json);
  static Future<String?> getOfflineUser() => _storage.read(key: _userKey);
  static Future<void> clearOfflineUser() =>
      _storage.delete(key: _userKey);

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
