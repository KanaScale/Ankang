import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/app/app_runtime_settings.dart';
import 'package:ankang_assistant/models/user_setting_model.dart';
import 'package:ankang_assistant/pages/profile/settings_controller.dart';
import 'package:ankang_assistant/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads persisted settings from profile service', () async {
    final service = _FakeProfileService();
    final controller = SettingsController(profileService: service);

    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.settings?.fontScale, 1.15);
    expect(controller.settings?.notificationEnabled, isFalse);
    expect(controller.settings?.largeTouchTarget, isTrue);
    expect(controller.settings?.simpleMode, isFalse);
    expect(AppRuntimeSettings.instance.fontScale, 1.15);
    expect(AppRuntimeSettings.instance.largeTouchTarget, isTrue);
  });

  test('saves settings and refreshes local state from response', () async {
    final service = _FakeProfileService();
    final controller = SettingsController(profileService: service);

    final saved = await controller.save(
      const UserSettingModel(
        fontScale: 1.3,
        notificationEnabled: true,
        largeTouchTarget: false,
        simpleMode: true,
      ),
    );

    expect(saved, isTrue);
    expect(controller.saving, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.settings?.fontScale, 1.3);
    expect(controller.settings?.notificationEnabled, isTrue);
    expect(controller.settings?.largeTouchTarget, isFalse);
    expect(controller.settings?.simpleMode, isTrue);
    expect(service.savedSettings?.simpleMode, isTrue);
    expect(AppRuntimeSettings.instance.fontScale, 1.3);
    expect(AppRuntimeSettings.instance.largeTouchTarget, isFalse);
    expect(AppRuntimeSettings.instance.simpleMode, isTrue);
  });
}

class _FakeProfileService extends ProfileService {
  UserSettingModel _settings = const UserSettingModel(
    fontScale: 1.15,
    notificationEnabled: false,
    largeTouchTarget: true,
    simpleMode: false,
  );

  UserSettingModel? savedSettings;

  @override
  Future<BaseResponse<UserSettingModel>> getSettings() async {
    return BaseResponse<UserSettingModel>(
      code: 200,
      message: 'success',
      data: _settings,
      success: true,
    );
  }

  @override
  Future<BaseResponse<UserSettingModel>> updateSettings(
    UserSettingModel settings,
  ) async {
    savedSettings = settings;
    _settings = settings;
    return BaseResponse<UserSettingModel>(
      code: 200,
      message: 'success',
      data: _settings,
      success: true,
    );
  }
}
