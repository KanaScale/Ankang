import 'emergency_dispatch_attempt_model.dart';

class EmergencyEventModel {
  const EmergencyEventModel({
    required this.id,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.address,
    this.status,
    this.message,
    this.contactsNotified = 0,
    this.clientEventId,
    this.triggeredAt,
    this.accuracyMeters,
    this.locationSource,
    this.attempts = const [],
  });

  final int id;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? status;
  final String? message;
  final int contactsNotified;
  final String? clientEventId;
  final DateTime? triggeredAt;
  final double? accuracyMeters;
  final String? locationSource;
  final List<EmergencyDispatchAttemptModel> attempts;

  factory EmergencyEventModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return EmergencyEventModel(
      id: json['id'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      status: json['status'] as String?,
      message: json['message'] as String?,
      contactsNotified: json['contactsNotified'] as int? ?? 0,
      clientEventId: json['clientEventId'] as String?,
      triggeredAt: DateTime.tryParse(json['triggeredAt'] as String? ?? ''),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      locationSource: json['locationSource'] as String?,
      attempts: ((json['attempts'] as List<dynamic>?) ?? [])
          .map(EmergencyDispatchAttemptModel.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'status': status,
        'message': message,
        'contactsNotified': contactsNotified,
        'clientEventId': clientEventId,
        'triggeredAt': triggeredAt?.toIso8601String(),
        'accuracyMeters': accuracyMeters,
        'locationSource': locationSource,
        'attempts': attempts.map((item) => item.toJson()).toList(),
      };
}
