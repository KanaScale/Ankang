import 'package:flutter/foundation.dart';

import '../../app/app_runtime_settings.dart';
import '../../models/user_setting_model.dart';
import '../../services/profile_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({ProfileService? profileService})
      : _profileService = profileService ?? ProfileService();

  final ProfileService _profileService;

  UserSettingModel? settings;
  bool loading = true;
  bool saving = false;
  String? errorMessage;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _profileService.getSettings();
      if (!response.success || response.data == null) {
        errorMessage = response.message.isEmpty ? '设置加载失败' : response.message;
        return;
      }
      settings = response.data;
      AppRuntimeSettings.instance.apply(settings!);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(UserSettingModel draft) async {
    saving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _profileService.updateSettings(draft);
      if (!response.success || response.data == null) {
        errorMessage = response.message.isEmpty ? '设置保存失败' : response.message;
        return false;
      }
      settings = response.data;
      AppRuntimeSettings.instance.apply(settings!);
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
