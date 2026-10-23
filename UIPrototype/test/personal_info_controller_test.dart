import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/user_model.dart';
import 'package:ankang_assistant/pages/profile/personal_info_controller.dart';
import 'package:ankang_assistant/services/auth_service.dart';
import 'package:ankang_assistant/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads personal info and writes it to current user cache', () async {
    final service = _FakeProfileService();
    final controller = PersonalInfoController(profileService: service);

    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.user?.username, 'demo_user');
    expect(AuthService.currentUser?.username, 'demo_user');
  });

  test('saves personal info through profile service', () async {
    final service = _FakeProfileService();
    final controller = PersonalInfoController(profileService: service);

    final saved = await controller.save(
      const PersonalInfoDraft(
        username: 'new_user',
        nickname: '新用户',
        phone: '13800138000',
        email: 'new@example.com',
        age: 66,
        gender: 'male',
      ),
    );

    expect(saved, isTrue);
    expect(controller.saving, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.user?.username, 'demo_user');
    expect(controller.user?.nickname, '新用户');
    expect(AuthService.currentUser?.username, 'demo_user');
  });

  test('clears editable personal info and lowers completion', () async {
    final service = _FakeProfileService();
    final controller = PersonalInfoController(profileService: service);

    final saved = await controller.save(
      const PersonalInfoDraft(
        username: 'changed_account_should_be_ignored',
        nickname: '',
        phone: '',
        email: '',
        age: null,
        gender: '',
      ),
    );

    expect(saved, isTrue);
    expect(controller.user?.username, 'demo_user');
    expect(controller.user?.nickname, isNull);
    expect(controller.user?.phone, isNull);
    expect(controller.user?.email, isNull);
    expect(controller.user?.age, isNull);
    expect(controller.user?.gender, isNull);
    expect(PersonalInfoDraft.fromUser(controller.user!).completion, 0);
    expect(service.lastUsername, isNull);
  });
}

class _FakeProfileService extends ProfileService {
  String? lastUsername;

  UserModel _user = const UserModel(
    id: 1,
    username: 'demo_user',
    nickname: '演示用户',
    phone: '13800138000',
    email: 'demo@example.com',
    age: 65,
    gender: 'female',
  );

  @override
  Future<BaseResponse<UserModel>> getCurrentUser() async {
    return BaseResponse<UserModel>(
      code: 200,
      message: 'success',
      data: _user,
      success: true,
    );
  }

  @override
  Future<BaseResponse<UserModel>> updateCurrentUser({
    String? username,
    String? nickname,
    String? phone,
    String? email,
    int? age,
    String? gender,
    String? avatarUrl,
  }) async {
    lastUsername = username;
    _user = UserModel(
      id: _user.id,
      username: _user.username,
      nickname: _blankToNull(nickname),
      phone: _blankToNull(phone),
      email: _blankToNull(email),
      age: age,
      gender: _blankToNull(gender),
      avatarUrl: avatarUrl,
    );
    return BaseResponse<UserModel>(
      code: 200,
      message: 'success',
      data: _user,
      success: true,
    );
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
