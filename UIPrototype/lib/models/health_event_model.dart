enum HealthRiskLevel { normal, elevated, high, unknown }

class HealthEventTimelineModel {
  const HealthEventTimelineModel({
    required this.stage,
    required this.message,
    required this.occurredAt,
  });

  final String stage;
  final String message;
  final DateTime occurredAt;

  factory HealthEventTimelineModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? const {};
    return HealthEventTimelineModel(
      stage: json['stage'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
      occurredAt: _dateTime(json['occurredAt'] ?? json['occurred_at']),
    );
  }
}

class HealthEventModel {
  const HealthEventModel({
    required this.eventId,
    required this.eventType,
    required this.healthRecordId,
    required this.status,
    required this.riskLevel,
    required this.riskScore,
    required this.summary,
    required this.reasons,
    required this.occurredAt,
    this.sosEventId,
    this.processedAt,
    this.timeline = const [],
  });

  final String eventId;
  final String eventType;
  final int healthRecordId;
  final String status;
  final HealthRiskLevel riskLevel;
  final int riskScore;
  final String summary;
  final List<String> reasons;
  final int? sosEventId;
  final DateTime occurredAt;
  final DateTime? processedAt;
  final List<HealthEventTimelineModel> timeline;

  bool get isFinished => status == 'completed' || status == 'failed';
  bool get needsAttention =>
      riskLevel == HealthRiskLevel.elevated ||
      riskLevel == HealthRiskLevel.high;

  factory HealthEventModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? const {};
    final reasons = json['reasons'] as List<dynamic>? ?? const [];
    final timeline = json['timeline'] as List<dynamic>? ?? const [];
    return HealthEventModel(
      eventId: json['eventId'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      healthRecordId: _integer(json['healthRecordId']) ?? 0,
      status: json['status'] as String? ?? 'unknown',
      riskLevel: HealthRiskLevelX.fromApiValue(json['riskLevel'] as String?),
      riskScore: _integer(json['riskScore']) ?? 0,
      summary: json['summary'] as String? ?? '',
      reasons: reasons.map((item) => item.toString()).toList(growable: false),
      sosEventId: _integer(json['sosEventId']),
      occurredAt: _dateTime(json['occurredAt'] ?? json['occurred_at']),
      processedAt:
          _nullableDateTime(json['processedAt'] ?? json['processed_at']),
      timeline: timeline
          .map(HealthEventTimelineModel.fromJson)
          .toList(growable: false),
    );
  }
}

extension HealthRiskLevelX on HealthRiskLevel {
  String get label => switch (this) {
        HealthRiskLevel.normal => '正常',
        HealthRiskLevel.elevated => '较高风险',
        HealthRiskLevel.high => '高风险',
        HealthRiskLevel.unknown => '待确认',
      };

  static HealthRiskLevel fromApiValue(String? value) => switch (value) {
        'normal' => HealthRiskLevel.normal,
        'elevated' => HealthRiskLevel.elevated,
        'high' => HealthRiskLevel.high,
        _ => HealthRiskLevel.unknown,
      };
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime _dateTime(Object? value) =>
    _nullableDateTime(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

DateTime? _nullableDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }
  return null;
}
