import 'package:flutter/foundation.dart';

import '../models/user_setting_model.dart';

class AppRuntimeSettings extends ChangeNotifier {
  AppRuntimeSettings._();

  static final AppRuntimeSettings instance = AppRuntimeSettings._();

  double fontScale = 1;
  bool notificationEnabled = true;
  bool largeTouchTarget = false;
  bool simpleMode = false;

  bool get showSecondaryInfo => !simpleMode;
  int get simpleListLimit => simpleMode ? 3 : 999;
  int get simpleChatHistoryLimit => simpleMode ? 4 : 999;

  void apply(UserSettingModel settings) {
    final nextFontScale = settings.fontScale.clamp(0.85, 1.3).toDouble();
    final changed = fontScale != nextFontScale ||
        notificationEnabled != settings.notificationEnabled ||
        largeTouchTarget != settings.largeTouchTarget ||
        simpleMode != settings.simpleMode;

    fontScale = nextFontScale;
    notificationEnabled = settings.notificationEnabled;
    largeTouchTarget = settings.largeTouchTarget;
    simpleMode = settings.simpleMode;

    if (changed) {
      notifyListeners();
    }
  }
}
