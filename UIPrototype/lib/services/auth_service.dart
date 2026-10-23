import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../app/app_runtime_settings.dart';
import '../models/base_response.dart';
import '../models/user_setting_model.dart';
import '../models/user_model.dart';
import '../utils/auth_preferences.dart';
import '../utils/token_storage.dart';
import 'api_client.dart';
import 'care_mode_service.dart';
import 'offline_session_coordinator.dart';

class AuthService {
  AuthService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  static UserModel? _currentUser;

  final ApiClient _apiClient;

  static UserModel? get currentUser => _currentUser;

  static void cacheCurrentUser(UserModel? user) {
    _currentUser = user;
  }

  Future<bool> restoreSession() async {
    final keepSignedIn = await AuthPreferences.isKeepSignedInEnabled();
    if (!keepSignedIn) {
      await TokenStorage.clearAuthSession();
      await TokenStorage.clearOfflineUser();
      return false;
    }
    try {
      final hasAccessToken = await TokenStorage.hasUsableAccessToken();
      final hasRefreshToken = await TokenStorage.hasUsableRefreshToken();
      if (!hasAccessToken && !hasRefreshToken) {
        await _clearLocalSession();
        return false;
      }

      final response = await _apiClient.get<UserModel>(
        '/users/me',
        parser: UserModel.fromJson,
        timeout: const Duration(seconds: 3),
      );
      final user = response.data;
      if (!response.success) {
        if (response.code == 401 || response.code == 403) {
          await _clearLocalSession();
          return false;
        }
        return await restoreOfflineSession() != null;
      }
      if (user == null || user.id <= 0) {
        await _clearLocalSession();
        return false;
      }

      _currentUser = user;
      await _loadRuntimeSettings();
      await OfflineSessionCoordinator.activate(user);
      await CareModeService.loadForUser(user.id);
      return true;
    } on ApiException catch (error) {
      if (error.kind == ApiFailureKind.authenticationRejected) {
        await _clearLocalSession();
        return false;
      }
      if (error.isTemporarilyUnavailable) {
        return await restoreOfflineSession() != null;
      }
      return false;
    } catch (_) {
      return await restoreOfflineSession() != null;
    }
  }

  Future<BaseResponse<LoginResult>> login({
    required String username,
    required String password,
    bool keepSignedIn = false,
  }) async {
    final response = await _apiClient.post<LoginResult>(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
        'keepSignedIn': keepSignedIn,
      },
      parser: LoginResult.fromJson,
    );
    final token = response.data?.token;
    if (response.success && token != null && token.isNotEmpty) {
      _currentUser = response.data?.user;
      await TokenStorage.saveAuthSession(
        accessToken: token,
        accessTokenExpiresInSeconds:
            response.data?.accessTokenExpiresInSeconds ?? 900,
        refreshToken: keepSignedIn ? response.data?.refreshToken : null,
        refreshTokenExpiresAt:
            keepSignedIn ? response.data?.refreshTokenExpiresAt : null,
      );
      if (_currentUser != null) {
        await TokenStorage.saveOfflineUser(jsonEncode(_currentUser!.toJson()));
      }
      await _loadRuntimeSettings();
      final user = _currentUser;
      if (user != null && user.id > 0) {
        await OfflineSessionCoordinator.activate(user);
        await CareModeService.loadForUser(user.id);
      } else {
        await OfflineSessionCoordinator.deactivate();
        await CareModeService.loadForUser(null);
      }
    } else {
      _currentUser = null;
      await OfflineSessionCoordinator.deactivate();
      CareModeService.clearRuntime();
      await TokenStorage.clearAuthSession();
    }
    return response;
  }

  Future<BaseResponse<UserModel>> register({
    required String username,
    required String password,
    String? confirmPassword,
    String? phone,
  }) async {
    return _apiClient.post<UserModel>(
      '/auth/register',
      data: {
        'username': username,
        'password': password,
        'confirmPassword': confirmPassword ?? password,
        'phone': phone,
      },
      parser: UserModel.fromJson,
    );
  }

  Future<BaseResponse<PasswordResetCodeResult>> sendPasswordResetCode({
    required String username,
    required String phone,
  }) {
    return _apiClient.post<PasswordResetCodeResult>(
      '/auth/password-reset/code',
      data: {
        'username': username,
        'phone': phone,
      },
      parser: PasswordResetCodeResult.fromJson,
    );
  }

  Future<BaseResponse<void>> resetPassword({
    required String username,
    required String phone,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _apiClient.post<void>(
      '/auth/password-reset',
      data: {
        'username': username,
        'phone': phone,
        'code': code,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<void> logout() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _apiClient.post<void>(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      } catch (_) {
        // Local logout must succeed even if the server is unavailable.
      }
    }
    await _clearLocalSession();
  }

  Future<void> _clearLocalSession() async {
    await OfflineSessionCoordinator.deactivate();
    _currentUser = null;
    CareModeService.clearRuntime();
    await AuthPreferences.disableAutoLogin();
    await TokenStorage.clearAuthSession();
    await TokenStorage.clearOfflineUser();
    AppRuntimeSettings.instance.apply(const UserSettingModel());
  }

  Future<void> handleUnauthorized() => _clearLocalSession();

  Future<void> handleAuthenticated() async {
    final user = _currentUser;
    if (user == null || !OfflineSessionCoordinator.isOfflineRestored) return;
    await OfflineSessionCoordinator.activate(user);
    await _loadRuntimeSettings();
    await CareModeService.loadForUser(user.id);
  }

  Future<UserModel?> restoreOfflineSession() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    if (!await AuthPreferences.isKeepSignedInEnabled() ||
        !await TokenStorage.hasUsableRefreshToken()) {
      return null;
    }
    final raw = await TokenStorage.getOfflineUser();
    if (raw == null) return null;
    try {
      final user = UserModel.fromJson(jsonDecode(raw));
      if (user.id <= 0) return null;
      _currentUser = user;
      await OfflineSessionCoordinator.activate(user, synchronize: false);
      OfflineSessionCoordinator.isOfflineRestored = true;
      await CareModeService.loadForUser(user.id);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRuntimeSettings() async {
    try {
      final response = await _apiClient.get<UserSettingModel>(
        '/profile/settings',
        parser: UserSettingModel.fromJson,
      );
      final settings = response.data;
      if (response.success && settings != null) {
        AppRuntimeSettings.instance.apply(settings);
      }
    } catch (_) {
      // Settings are best-effort at login; the settings page can retry later.
    }
  }
}

class PasswordResetCodeResult {
  const PasswordResetCodeResult({
    required this.message,
    this.devCode,
    this.expiresInSeconds = 300,
  });

  final String message;
  final String? devCode;
  final int expiresInSeconds;

  factory PasswordResetCodeResult.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return PasswordResetCodeResult(
      message: json['message'] as String? ?? '验证码已发送',
      devCode: json['devCode'] as String?,
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 300,
    );
  }
}
