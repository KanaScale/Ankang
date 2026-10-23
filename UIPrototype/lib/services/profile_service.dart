import '../models/base_response.dart';
import '../models/health_goal_model.dart';
import '../models/health_profile_model.dart';
import '../models/user_model.dart';
import '../models/user_setting_model.dart';
import 'api_client.dart';

class ProfileService {
  ProfileService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<UserModel>> getCurrentUser() {
    return _apiClient.get<UserModel>('/users/me', parser: UserModel.fromJson);
  }

  Future<BaseResponse<UserModel>> updateCurrentUser({
    String? username,
    String? nickname,
    String? phone,
    String? email,
    int? age,
    String? gender,
    String? avatarUrl,
  }) {
    return _apiClient.put<UserModel>(
      '/user/profile',
      data: {
        'nickname': nickname,
        'phone': phone,
        'email': email,
        'age': age,
        'gender': gender,
        'avatarUrl': avatarUrl,
      },
      parser: UserModel.fromJson,
    );
  }

  Future<BaseResponse<void>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _apiClient.put<void>(
      '/user/password',
      data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<BaseResponse<HealthProfileModel>> getHealthProfile() {
    return _apiClient.get<HealthProfileModel>(
      '/profile/health',
      parser: HealthProfileModel.fromJson,
    );
  }

  Future<BaseResponse<HealthProfileModel>> updateHealthProfile(
    HealthProfileModel profile,
  ) {
    return _apiClient.put<HealthProfileModel>(
      '/profile/health',
      data: profile.toJson(),
      parser: HealthProfileModel.fromJson,
    );
  }

  Future<BaseResponse<HealthGoalModel>> getHealthGoals() {
    return _apiClient.get<HealthGoalModel>(
      '/profile/goals',
      parser: HealthGoalModel.fromJson,
    );
  }

  Future<BaseResponse<HealthGoalProgressModel>> getHealthGoalProgress() {
    return _apiClient.get<HealthGoalProgressModel>(
      '/profile/goals/progress',
      parser: HealthGoalProgressModel.fromJson,
    );
  }

  Future<BaseResponse<HealthGoalModel>> updateHealthGoals(
    HealthGoalModel goals,
  ) {
    return _apiClient.put<HealthGoalModel>(
      '/profile/goals',
      data: goals.toJson(),
      parser: HealthGoalModel.fromJson,
    );
  }

  Future<BaseResponse<UserSettingModel>> getSettings() {
    return _apiClient.get<UserSettingModel>(
      '/profile/settings',
      parser: UserSettingModel.fromJson,
    );
  }

  Future<BaseResponse<UserSettingModel>> updateSettings(
    UserSettingModel settings,
  ) {
    return _apiClient.put<UserSettingModel>(
      '/profile/settings',
      data: settings.toJson(),
      parser: UserSettingModel.fromJson,
    );
  }
}
