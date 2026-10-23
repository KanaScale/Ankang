import 'package:ankang_assistant/config/api_config.dart';
import 'package:ankang_assistant/config/app_config.dart';
import 'package:ankang_assistant/utils/date_util.dart';
import 'package:ankang_assistant/utils/validator_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Configuration', () {
    test('uses dev api base url by default', () {
      expect(ApiConfig.environment, AppEnvironment.dev);
      expect(ApiConfig.baseUrl, 'https://api.ankangxai.cn/api');
      expect(AppConfig.appName, '安康助手');
      expect(AppConfig.defaultPageSize, 20);
    });
  });

  group('ValidatorUtil', () {
    test('validates required fields', () {
      expect(ValidatorUtil.required('abc'), isNull);
      expect(ValidatorUtil.required('   '), '请输入内容');
    });

    test('validates phone number', () {
      expect(ValidatorUtil.phone('13800138000'), isNull);
      expect(ValidatorUtil.phone('123'), '请输入正确的手机号');
    });

    test('validates password length', () {
      expect(ValidatorUtil.password('123456'), isNull);
      expect(ValidatorUtil.password('123'), '密码至少 6 位');
    });
  });

  group('DateUtil', () {
    test('formats date and time consistently', () {
      final date = DateTime(2026, 7, 6, 9, 5);

      expect(DateUtil.formatDate(date), '2026-07-06');
      expect(DateUtil.formatTime(date), '09:05');
      expect(DateUtil.formatDateTime(date), '2026-07-06 09:05');
    });
  });
}
