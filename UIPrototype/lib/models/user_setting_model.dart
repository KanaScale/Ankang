class UserSettingModel {
  const UserSettingModel({
    this.fontScale = 1,
    this.notificationEnabled = true,
    this.largeTouchTarget = false,
    this.simpleMode = false,
  });

  final double fontScale;
  final bool notificationEnabled;
  final bool largeTouchTarget;
  final bool simpleMode;

  factory UserSettingModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return UserSettingModel(
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1,
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      largeTouchTarget: json['largeTouchTarget'] as bool? ?? false,
      simpleMode: json['simpleMode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontScale': fontScale,
        'notificationEnabled': notificationEnabled,
        'largeTouchTarget': largeTouchTarget,
        'simpleMode': simpleMode,
      };
}
