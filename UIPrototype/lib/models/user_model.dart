class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    this.nickname,
    this.phone,
    this.email,
    this.gender,
    this.age,
    this.avatarUrl,
    this.role = 'PATIENT',
  });

  final int id;
  final String username;
  final String? nickname;
  final String? phone;
  final String? email;
  final String? gender;
  final int? age;
  final String? avatarUrl;
  final String role;

  factory UserModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return UserModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      gender: json['gender'] as String?,
      age: json['age'] as int?,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'PATIENT',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'nickname': nickname,
        'phone': phone,
        'email': email,
        'gender': gender,
        'age': age,
        'avatarUrl': avatarUrl,
        'role': role,
      };
}

class LoginResult {
  const LoginResult({
    required this.token,
    this.refreshToken,
    this.accessTokenExpiresInSeconds = 900,
    this.refreshTokenExpiresAt,
    this.user,
  });

  final String token;
  final String? refreshToken;
  final int accessTokenExpiresInSeconds;
  final DateTime? refreshTokenExpiresAt;
  final UserModel? user;

  factory LoginResult.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return LoginResult(
      token: json['token'] as String? ?? json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      accessTokenExpiresInSeconds:
          json['accessTokenExpiresInSeconds'] as int? ?? 900,
      refreshTokenExpiresAt:
          DateTime.tryParse(json['refreshTokenExpiresAt'] as String? ?? ''),
      user: json['user'] == null ? null : UserModel.fromJson(json['user']),
    );
  }
}

class AuthTokenResult {
  const AuthTokenResult({
    required this.token,
    required this.refreshToken,
    required this.accessTokenExpiresInSeconds,
    required this.refreshTokenExpiresAt,
  });

  final String token;
  final String refreshToken;
  final int accessTokenExpiresInSeconds;
  final DateTime refreshTokenExpiresAt;

  factory AuthTokenResult.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    final refreshExpiresAt =
        DateTime.tryParse(json['refreshTokenExpiresAt'] as String? ?? '');
    return AuthTokenResult(
      token: json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      accessTokenExpiresInSeconds:
          json['accessTokenExpiresInSeconds'] as int? ?? 900,
      refreshTokenExpiresAt:
          refreshExpiresAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
