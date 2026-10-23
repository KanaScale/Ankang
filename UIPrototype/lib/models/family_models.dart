import 'agent_chat_model.dart';
import 'emergency_event_model.dart';
import 'health_record_model.dart';
import 'reminder_model.dart';

class FamilyInviteModel {
  const FamilyInviteModel({
    required this.inviteCode,
    required this.expireAt,
  });

  final String inviteCode;
  final DateTime? expireAt;

  factory FamilyInviteModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return FamilyInviteModel(
      inviteCode: json['inviteCode'] as String? ?? '',
      expireAt: _parseDateTime(json['expireAt']),
    );
  }
}

class BoundPatientModel {
  const BoundPatientModel({
    required this.patientUserId,
    required this.patientName,
    this.relationType = 'other',
    this.status = 'ACTIVE',
    this.riskLevel = 'unknown',
    this.lastUpdateTime,
    this.permissions = const [],
  });

  final int patientUserId;
  final String patientName;
  final String relationType;
  final String status;
  final String riskLevel;
  final DateTime? lastUpdateTime;
  final List<String> permissions;

  factory BoundPatientModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return BoundPatientModel(
      patientUserId: _asInt(json['patientUserId']) ?? 0,
      patientName: json['patientName'] as String? ?? '未命名家人',
      relationType: json['relationType'] as String? ?? 'other',
      status: json['status'] as String? ?? 'ACTIVE',
      riskLevel: json['riskLevel'] as String? ?? 'unknown',
      lastUpdateTime: _parseDateTime(json['lastUpdateTime']),
      permissions: _stringList(json['permissions']),
    );
  }
}

class FamilyHealthSummaryModel {
  const FamilyHealthSummaryModel({
    required this.patientUserId,
    required this.patientName,
    required this.healthScore,
    required this.status,
    this.lastUpdateTime,
    this.metrics = const [],
  });

  final int patientUserId;
  final String patientName;
  final int healthScore;
  final String status;
  final DateTime? lastUpdateTime;
  final List<FamilyHealthMetricModel> metrics;

  factory FamilyHealthSummaryModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    final summary = json['summary'] as Map<String, dynamic>? ?? json;
    return FamilyHealthSummaryModel(
      patientUserId: _asInt(json['patientUserId']) ?? 0,
      patientName: json['patientName'] as String? ?? '未命名家人',
      lastUpdateTime: _parseDateTime(json['lastUpdateTime']),
      healthScore: _asInt(summary['healthScore']) ?? 0,
      status: summary['status'] as String? ?? '暂无健康记录',
      metrics: ((summary['metrics'] as List<dynamic>?) ?? [])
          .map(FamilyHealthMetricModel.fromJson)
          .toList(),
    );
  }
}

class FamilyHealthMetricModel {
  const FamilyHealthMetricModel({
    required this.type,
    required this.name,
    required this.value,
    this.unit = '',
    this.status = 'normal',
    this.trend = '',
  });

  final String type;
  final String name;
  final String value;
  final String unit;
  final String status;
  final String trend;

  factory FamilyHealthMetricModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return FamilyHealthMetricModel(
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      value: json['value']?.toString() ?? '--',
      unit: json['unit'] as String? ?? '',
      status: json['status'] as String? ?? 'normal',
      trend: json['trend']?.toString() ?? '',
    );
  }
}

typedef FamilyHealthRecordModel = HealthRecordModel;
typedef FamilyReminderModel = ReminderModel;
typedef FamilySosEventModel = EmergencyEventModel;
typedef FamilyAgentReplyModel = AgentReplyModel;

DateTime? _parseDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _stringList(Object? value) {
  return ((value as List<dynamic>?) ?? [])
      .whereType<String>()
      .where((item) => item.trim().isNotEmpty)
      .toList();
}
