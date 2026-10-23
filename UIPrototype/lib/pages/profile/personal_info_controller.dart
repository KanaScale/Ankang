import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

class PersonalInfoDraft {
  const PersonalInfoDraft({
    required this.username,
    required this.nickname,
    required this.phone,
    required this.email,
    required this.age,
    required this.gender,
    this.avatarUrl,
  });

  final String username;
  final String nickname;
  final String phone;
  final String email;
  final int? age;
  final String gender;
  final String? avatarUrl;

  factory PersonalInfoDraft.fromUser(UserModel user) {
    return PersonalInfoDraft(
      username: user.username,
      nickname: user.nickname ?? '',
      phone: user.phone ?? '',
      email: user.email ?? '',
      age: user.age,
      gender: user.gender ?? '',
      avatarUrl: user.avatarUrl,
    );
  }

  double get completion {
    const total = 5;
    var filled = 0;
    if (nickname.trim().isNotEmpty) {
      filled++;
    }
    if (phone.trim().isNotEmpty) {
      filled++;
    }
    if (email.trim().isNotEmpty) {
      filled++;
    }
    if (age != null) {
      filled++;
    }
    if (gender.trim().isNotEmpty) {
      filled++;
    }
    return filled / total;
  }
}

class PersonalInfoController extends ChangeNotifier {
  PersonalInfoController({ProfileService? profileService})
      : _profileService = profileService ?? ProfileService();

  final ProfileService _profileService;

  UserModel? user;
  bool loading = true;
  bool saving = false;
  String? errorMessage;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _profileService.getCurrentUser();
      if (!response.success || response.data == null) {
        errorMessage = response.message.isEmpty ? '用户信息加载失败' : response.message;
        return;
      }
      user = response.data;
      AuthService.cacheCurrentUser(user);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(PersonalInfoDraft draft) async {
    saving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _profileService.updateCurrentUser(
        nickname: draft.nickname.trim(),
        phone: draft.phone.trim(),
        email: draft.email.trim(),
        age: draft.age,
        gender: draft.gender.trim(),
        avatarUrl: draft.avatarUrl,
      );
      if (!response.success || response.data == null) {
        errorMessage = response.message.isEmpty ? '用户信息保存失败' : response.message;
        return false;
      }
      user = response.data;
      AuthService.cacheCurrentUser(user);
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

}
