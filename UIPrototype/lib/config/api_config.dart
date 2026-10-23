enum AppEnvironment { dev, test, prod }

class ApiConfig {
  ApiConfig._();

  static const AppEnvironment environment = AppEnvironment.dev;

  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get devBaseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl;
    }
    return 'https://api.ankangxai.cn/api';
  }

  static const String testBaseUrl = 'https://test-api.example.com/api';
  static const String prodBaseUrl = 'https://api.ankangxai.cn/api';

  static String get baseUrl {
    switch (environment) {
      case AppEnvironment.dev:
        return devBaseUrl;
      case AppEnvironment.test:
        return testBaseUrl;
      case AppEnvironment.prod:
        return prodBaseUrl;
    }
  }
}
