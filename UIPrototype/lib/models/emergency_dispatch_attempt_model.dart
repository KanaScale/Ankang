class EmergencyDispatchAttemptModel {
  const EmergencyDispatchAttemptModel({
    required this.attemptId,
    required this.channel,
    required this.status,
    required this.occurredAt,
    this.contactId,
    this.errorCode,
    this.clientEventId,
    this.contactName,
  });

  final String attemptId;
  final int? contactId;
  final String channel;
  final String status;
  final String? errorCode;
  final String? clientEventId;
  final String? contactName;
  final DateTime occurredAt;

  factory EmergencyDispatchAttemptModel.fromJson(Object? source) {
    final raw = source as Map<Object?, Object?>? ?? const {};
    final json = raw.map(
      (key, value) => MapEntry(key?.toString() ?? '', value),
    );
    final occurredAtMillis = (json['occurredAtMillis'] as num?)?.toInt();
    return EmergencyDispatchAttemptModel(
      attemptId: json['attemptId'] as String? ?? '',
      contactId: json['contactId'] as int?,
      channel: json['channel'] as String? ?? '',
      status: json['status'] as String? ?? '',
      errorCode: json['errorCode'] as String?,
      clientEventId: json['clientEventId'] as String?,
      contactName: json['contactName'] as String?,
      occurredAt: occurredAtMillis == null
          ? DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
              DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(occurredAtMillis),
    );
  }

  Map<String, dynamic> toJson() => {
        'attemptId': attemptId,
        'contactId': contactId,
        'channel': channel,
        'status': status,
        'errorCode': errorCode,
        'occurredAt': occurredAt.toIso8601String(),
      };
}
