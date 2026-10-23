class ValidatorUtil {
  ValidatorUtil._();

  static const int accountMinLength = 4;
  static const int accountMaxLength = 20;
  static const int usernameMaxLength = 20;

  static String? required(String? value, {String message = '请输入内容'}) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? accountName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '请输入账号';
    }
    if (trimmed.length < accountMinLength ||
        trimmed.length > accountMaxLength) {
      return '账号长度需为 4-20 个字符';
    }
    return null;
  }

  static String? optionalUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > usernameMaxLength) {
      return '用户名不能超过 20 个字符';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入手机号';
    }
    final matched = RegExp(r'^1[3-9]\d{9}$').hasMatch(value.trim());
    return matched ? null : '请输入正确的手机号';
  }

  static String? password(String? value) {
    if (value == null || value.length < 6) {
      return '密码至少 6 位';
    }
    return null;
  }
}
