class LocalSosEventModel {
  const LocalSosEventModel({
    required this.ownerUserId,
    required this.clientEventId,
    required this.triggeredAt,
    required this.locationSource,
    required this.message,
    required this.syncPending,
    this.executionState = SosExecutionState.completed,
    this.syncError,
    this.updatedAt,
    this.contactSnapshot = const [],
    this.latitude,
    this.longitude,
    this.accuracyMeters,
  });

  final int ownerUserId;
  final String clientEventId;
  final DateTime triggeredAt;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String locationSource;
  final String message;
  final bool syncPending;
  final SosExecutionState executionState;
  final String? syncError;
  final DateTime? updatedAt;
  final List<Map<String, dynamic>> contactSnapshot;

  factory LocalSosEventModel.fromJson(Object? source) {
    final raw = source as Map<Object?, Object?>? ?? const {};
    final triggeredAtMillis = (raw['triggeredAtMillis'] as num?)?.toInt() ?? 0;
    return LocalSosEventModel(
      ownerUserId: (raw['ownerUserId'] as num?)?.toInt() ?? 0,
      clientEventId: raw['clientEventId'] as String? ?? '',
      triggeredAt: DateTime.fromMillisecondsSinceEpoch(triggeredAtMillis),
      latitude: (raw['latitude'] as num?)?.toDouble(),
      longitude: (raw['longitude'] as num?)?.toDouble(),
      accuracyMeters: (raw['accuracyMeters'] as num?)?.toDouble(),
      locationSource: raw['locationSource'] as String? ?? 'unavailable',
      message: raw['message'] as String? ?? '',
      syncPending: raw['syncPending'] as bool? ?? true,
      executionState: SosExecutionState.values.firstWhere(
        (value) => value.name == raw['executionState'],
        orElse: () => SosExecutionState.completed,
      ),
      syncError: raw['syncError'] as String?,
      updatedAt: (raw['updatedAtMillis'] as num?) == null ? null : DateTime.fromMillisecondsSinceEpoch((raw['updatedAtMillis'] as num).toInt()),
      contactSnapshot: ((raw['contactSnapshot'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toPlatformMap() => {
        'ownerUserId': ownerUserId,
        'clientEventId': clientEventId,
        'triggeredAtMillis': triggeredAt.millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'locationSource': locationSource,
        'message': message,
        'executionState': executionState.name,
        'syncError': syncError,
        'contactSnapshot': contactSnapshot,
      };

  LocalSosEventModel copyWith({SosExecutionState? executionState, String? syncError, bool? syncPending}) => LocalSosEventModel(
    ownerUserId: ownerUserId, clientEventId: clientEventId, triggeredAt: triggeredAt,
    locationSource: locationSource, message: message, syncPending: syncPending ?? this.syncPending,
    latitude: latitude, longitude: longitude, accuracyMeters: accuracyMeters,
    executionState: executionState ?? this.executionState, syncError: syncError ?? this.syncError,
    updatedAt: DateTime.now(), contactSnapshot: contactSnapshot,
  );
}

enum SosExecutionState { prepared, dispatching, completed, unknown }
