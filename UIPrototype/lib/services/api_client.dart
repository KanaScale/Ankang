import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../config/app_config.dart';
import '../models/base_response.dart';
import '../models/user_model.dart';
import '../utils/token_storage.dart';

typedef JsonParser<T> = T Function(Object? json);

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiFailureKind.other,
  });

  final String message;
  final int? statusCode;
  final ApiFailureKind kind;

  bool get isTemporarilyUnavailable =>
      kind == ApiFailureKind.network ||
      kind == ApiFailureKind.serviceUnavailable;

  @override
  String toString() => message;
}

enum ApiFailureKind {
  network,
  serviceUnavailable,
  authenticationRejected,
  other,
}

enum AuthRefreshDisposition {
  success,
  rejected,
  unavailable,
}

class AuthRefreshResult {
  const AuthRefreshResult._(
    this.disposition, {
    this.accessToken,
    this.error,
  });

  const AuthRefreshResult.success(String accessToken)
      : this._(
          AuthRefreshDisposition.success,
          accessToken: accessToken,
        );

  const AuthRefreshResult.rejected()
      : this._(AuthRefreshDisposition.rejected);

  const AuthRefreshResult.unavailable(DioException error)
      : this._(AuthRefreshDisposition.unavailable, error: error);

  final AuthRefreshDisposition disposition;
  final String? accessToken;
  final DioException? error;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  Future<void> Function()? onUnauthorized;
  Future<void> Function()? onAuthenticated;
  Future<AuthRefreshResult>? _refreshFuture;

  void initialize({Dio? dio}) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        );

    _dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.extra['skipAuth'] != true) {
              final token = await TokenStorage.getToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
            if (kDebugMode) {
              debugPrint('[API] ${options.method} ${options.uri}');
            }
            handler.next(options);
          },
          onResponse: (response, handler) async {
            if (response.requestOptions.extra['skipAuth'] != true &&
                response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300) {
              final callback = onAuthenticated;
              if (callback != null) await callback();
            }
            handler.next(response);
          },
          onError: (error, handler) async {
            final statusCode = error.response?.statusCode;
            final options = error.requestOptions;
            final canRefresh = statusCode == 401 &&
                options.extra['skipAuthRefresh'] != true &&
                options.extra['authRetried'] != true &&
                !_isAuthPath(options.path);
            if (canRefresh) {
              final refreshResult = await _refreshAccessToken();
              if (refreshResult.disposition ==
                  AuthRefreshDisposition.success) {
                options.extra['authRetried'] = true;
                options.headers['Authorization'] =
                    'Bearer ${refreshResult.accessToken}';
                try {
                  final response = await _dio.fetch<Object?>(options);
                  handler.resolve(response);
                  return;
                } on DioException catch (retryError) {
                  if (_isTemporaryFailure(retryError)) {
                    handler.reject(retryError);
                    return;
                  }
                }
              }
              if (refreshResult.disposition ==
                  AuthRefreshDisposition.unavailable) {
                handler.reject(
                  refreshResult.error ?? _refreshUnavailableError(options),
                );
                return;
              }
              if (refreshResult.disposition ==
                  AuthRefreshDisposition.rejected) {
                await TokenStorage.clearAuthSession();
                final callback = onUnauthorized;
                if (callback != null) await callback();
              }
            }
            handler.next(error);
          },
        ),
      );
  }

  bool _isAuthPath(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/register') ||
      path.contains('/auth/refresh') ||
      path.contains('/auth/logout') ||
      path.contains('/auth/password-reset');

  Future<AuthRefreshResult> _refreshAccessToken() async {
    final pending = _refreshFuture;
    if (pending != null) return pending;
    final refresh = _performRefresh();
    _refreshFuture = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshFuture, refresh)) {
        _refreshFuture = null;
      }
    }
  }

  Future<AuthRefreshResult> _performRefresh() async {
    if (!await TokenStorage.hasUsableRefreshToken()) {
      return const AuthRefreshResult.rejected();
    }
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return const AuthRefreshResult.rejected();
    }
    try {
      final response = await _dio.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(
          extra: const {
            'skipAuth': true,
            'skipAuthRefresh': true,
          },
        ),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        return AuthRefreshResult.unavailable(
          _refreshUnavailableError(response.requestOptions),
        );
      }
      final envelope = BaseResponse<AuthTokenResult>.fromJson(
        body,
        AuthTokenResult.fromJson,
      );
      final tokens = envelope.data;
      if (!envelope.success ||
          tokens == null ||
          tokens.token.isEmpty ||
          tokens.refreshToken.isEmpty) {
        return _isAuthenticationRejection(envelope.code)
            ? const AuthRefreshResult.rejected()
            : AuthRefreshResult.unavailable(
                _refreshUnavailableError(response.requestOptions),
              );
      }
      await TokenStorage.saveAuthSession(
        accessToken: tokens.token,
        accessTokenExpiresInSeconds: tokens.accessTokenExpiresInSeconds,
        refreshToken: tokens.refreshToken,
        refreshTokenExpiresAt: tokens.refreshTokenExpiresAt,
      );
      return AuthRefreshResult.success(tokens.token);
    } on DioException catch (error) {
      return _isAuthenticationRejection(error.response?.statusCode)
          ? const AuthRefreshResult.rejected()
          : AuthRefreshResult.unavailable(error);
    }
  }

  static bool _isAuthenticationRejection(int? statusCode) =>
      statusCode == 400 || statusCode == 401 || statusCode == 403;

  static bool _isUnauthorizedStatus(int? statusCode) =>
      statusCode == 401 || statusCode == 403;

  static bool _isTemporaryFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == null || statusCode == 429 || statusCode >= 500;
  }

  DioException _refreshUnavailableError(RequestOptions options) => DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'refresh_temporarily_unavailable',
      );

  Future<BaseResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    JsonParser<T>? parser,
    Duration? timeout,
  }) {
    return request<T>(
      path,
      method: 'GET',
      queryParameters: queryParameters,
      parser: parser,
      timeout: timeout,
    );
  }

  Future<BaseResponse<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    JsonParser<T>? parser,
  }) {
    return request<T>(
      path,
      method: 'POST',
      data: data,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  Future<BaseResponse<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    JsonParser<T>? parser,
  }) {
    return request<T>(
      path,
      method: 'PUT',
      data: data,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  Future<BaseResponse<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    JsonParser<T>? parser,
  }) {
    return request<T>(
      path,
      method: 'DELETE',
      data: data,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  Future<BaseResponse<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    JsonParser<T>? parser,
    Duration? timeout,
  }) async {
    final cancelToken = CancelToken();
    try {
      final request = _dio.request<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method),
        cancelToken: cancelToken,
      );
      final response = timeout == null
          ? await request
          : await request.timeout(
              timeout,
              onTimeout: () {
                cancelToken.cancel('session_restore_timeout');
                throw const ApiException(
                  '网络暂不可用，已进入离线模式',
                  kind: ApiFailureKind.network,
                );
              },
            );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return BaseResponse<T>.fromJson(body, parser);
      }
      return BaseResponse<T>(
        code: response.statusCode ?? 200,
        message: 'success',
        data: parser == null ? body as T? : parser(body),
        success: true,
      );
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      throw ApiException(
        _messageFromDioError(error),
        statusCode: statusCode,
        kind: _failureKind(error),
      );
    }
  }

  ApiFailureKind _failureKind(DioException error) {
    final statusCode = error.response?.statusCode;
    if (_isUnauthorizedStatus(statusCode)) {
      return ApiFailureKind.authenticationRejected;
    }
    if (statusCode == 429 || (statusCode != null && statusCode >= 500)) {
      return ApiFailureKind.serviceUnavailable;
    }
    if (statusCode == null &&
        error.type != DioExceptionType.cancel &&
        error.type != DioExceptionType.badCertificate) {
      return ApiFailureKind.network;
    }
    return ApiFailureKind.other;
  }

  String _messageFromDioError(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      return responseData['message'] as String? ??
          responseData['msg'] as String? ??
          '请求失败';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return '请求超时，请稍后重试';
      case DioExceptionType.badResponse:
        return '服务器异常：${error.response?.statusCode ?? ''}';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '网络连接失败';
      case DioExceptionType.badCertificate:
        return '证书校验失败';
      case DioExceptionType.unknown:
        return '网络异常，请稍后重试';
    }
  }
}
