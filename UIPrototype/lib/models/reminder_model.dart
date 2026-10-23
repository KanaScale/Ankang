enum ReminderType { medicine, bloodPressure, bloodSugar, checkup, other }

enum ReminderRepeatType { once, daily, weekly }

enum ReminderSyncState { synced, pending, failed }

class ReminderModel {
  static const Object _unset = Object();

  const ReminderModel({
    required this.id,
    required this.title,
    required this.type,
    required this.remindAt,
    required this.repeatType,
    this.enabled = true,
    this.completed = false,
    this.remark,
    this.clientReminderId,
    this.syncState = ReminderSyncState.synced,
  });

  final int id;
  final String title;
  final ReminderType type;
  final DateTime remindAt;
  final ReminderRepeatType repeatType;
  final bool enabled;
  final bool completed;
  final String? remark;
  final String? clientReminderId;
  final ReminderSyncState syncState;

  factory ReminderModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return ReminderModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      type: _typeFromString(json['type'] as String?),
      remindAt: DateTime.tryParse(json['remindAt'] as String? ?? '') ??
          DateTime.now(),
      repeatType: _repeatFromString(json['repeatType'] as String?),
      enabled: json['enabled'] as bool? ?? true,
      completed: json['completed'] as bool? ?? false,
      remark: json['remark'] as String?,
      clientReminderId: json['clientReminderId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientReminderId': clientReminderId,
        'title': title,
        'type': type.name,
        'remindAt': remindAt.toIso8601String(),
        'repeatType': repeatType.name,
        'enabled': enabled,
        'remark': remark,
      };

  /// 未传入的字段会保留原值；显式传入 `remark: null` 时可清空备注。
  ReminderModel copyWith({
    int? id,
    String? title,
    ReminderType? type,
    DateTime? remindAt,
    ReminderRepeatType? repeatType,
    bool? enabled,
    bool? completed,
    Object? remark = _unset,
    String? clientReminderId,
    ReminderSyncState? syncState,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      remindAt: remindAt ?? this.remindAt,
      repeatType: repeatType ?? this.repeatType,
      enabled: enabled ?? this.enabled,
      completed: completed ?? this.completed,
      remark: identical(remark, _unset) ? this.remark : remark as String?,
      clientReminderId: clientReminderId ?? this.clientReminderId,
      syncState: syncState ?? this.syncState,
    );
  }

  static ReminderType _typeFromString(String? value) {
    return ReminderType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ReminderType.other,
    );
  }

  static ReminderRepeatType _repeatFromString(String? value) {
    return ReminderRepeatType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ReminderRepeatType.once,
    );
  }
}
