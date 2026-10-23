import 'package:ankang_assistant/services/api_client.dart';
import 'package:ankang_assistant/utils/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('offline session policy', () {
    test('network and service failures are temporary', () {
      expect(
        const ApiException(
          'offline',
          kind: ApiFailureKind.network,
        ).isTemporarilyUnavailable,
        isTrue,
      );
      expect(
        const ApiException(
          'server busy',
          statusCode: 503,
          kind: ApiFailureKind.serviceUnavailable,
        ).isTemporarilyUnavailable,
        isTrue,
      );
    });

    test('authentication rejection is not an offline fallback', () {
      expect(
        const ApiException(
          'rejected',
          statusCode: 401,
          kind: ApiFailureKind.authenticationRejected,
        ).isTemporarilyUnavailable,
        isFalse,
      );
    });

    test('expired access token does not invalidate usable refresh token',
        () async {
      final now = DateTime.now();
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'expired-access',
        'auth_access_token_expires_at':
            now.subtract(const Duration(minutes: 1)).toUtc().toIso8601String(),
        'auth_refresh_token': 'usable-refresh',
        'auth_refresh_token_expires_at':
            now.add(const Duration(days: 1)).toUtc().toIso8601String(),
      });

      expect(await TokenStorage.hasUsableAccessToken(now: now), isFalse);
      expect(await TokenStorage.hasUsableRefreshToken(now: now), isTrue);
    });

    test('expired refresh token cannot authorize offline access', () async {
      final now = DateTime.now();
      FlutterSecureStorage.setMockInitialValues({
        'auth_refresh_token': 'expired-refresh',
        'auth_refresh_token_expires_at':
            now.subtract(const Duration(minutes: 1)).toUtc().toIso8601String(),
      });

      expect(await TokenStorage.hasUsableRefreshToken(now: now), isFalse);
    });
  });
}
