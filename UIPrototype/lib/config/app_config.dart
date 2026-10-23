class AppConfig {
  AppConfig._();

  static const String appName = '安康助手';
  static const String version = '1.0.0';
  static const bool showDebugBanner = false;
  static const int defaultPageSize = 20;
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 60);
}
