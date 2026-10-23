enum SosPermissionState { granted, denied, notGranted, unavailable }

class SosDeviceReadiness {
  const SosDeviceReadiness({
    required this.supported,
    required this.smsPermission,
    required this.callPermission,
    required this.locationPermission,
    required this.locationServiceEnabled,
    required this.simSlotCount,
    required this.activeSimCount,
    this.defaultSmsSubscriptionId,
  });

  const SosDeviceReadiness.unsupported()
      : supported = false,
        smsPermission = SosPermissionState.unavailable,
        callPermission = SosPermissionState.unavailable,
        locationPermission = 'unavailable',
        locationServiceEnabled = false,
        defaultSmsSubscriptionId = null,
        simSlotCount = 0,
        activeSimCount = 0;

  final bool supported;
  final SosPermissionState smsPermission;
  final SosPermissionState callPermission;
  final String locationPermission;
  final bool locationServiceEnabled;
  final int? defaultSmsSubscriptionId;
  final int simSlotCount;
  final int activeSimCount;

  bool get hasDefaultSmsSim => defaultSmsSubscriptionId != null;

  bool get needsDefaultSmsSim => activeSimCount > 1 && !hasDefaultSmsSim;

  factory SosDeviceReadiness.fromMap(Map<Object?, Object?> source) {
    return SosDeviceReadiness(
      supported: source['supported'] as bool? ?? false,
      smsPermission: _permission(source['smsPermission']),
      callPermission: _permission(source['callPermission']),
      locationPermission: source['locationPermission'] as String? ?? 'unavailable',
      locationServiceEnabled:
          source['locationServiceEnabled'] as bool? ?? false,
      defaultSmsSubscriptionId:
          (source['defaultSmsSubscriptionId'] as num?)?.toInt(),
      simSlotCount: (source['simSlotCount'] as num?)?.toInt() ?? 0,
      activeSimCount: (source['activeSimCount'] as num?)?.toInt() ?? 0,
    );
  }

  static SosPermissionState _permission(Object? value) {
    return switch (value) {
      'granted' => SosPermissionState.granted,
      'denied' => SosPermissionState.denied,
      'not_granted' => SosPermissionState.notGranted,
      _ => SosPermissionState.unavailable,
    };
  }
}

class SosLocationResult {
  const SosLocationResult({
    required this.source,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
    this.errorCode,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String source;
  final DateTime? capturedAt;
  final String? errorCode;

  bool get available => latitude != null && longitude != null;

  String? get amapUrl => available
      ? 'https://uri.amap.com/marker?position=$longitude,$latitude'
          '&coordinate=wgs84&name=SOS%E6%B1%82%E5%8A%A9%E4%BD%8D%E7%BD%AE'
      : null;

  factory SosLocationResult.fromMap(Map<Object?, Object?> source) {
    final capturedAtMillis = (source['capturedAtMillis'] as num?)?.toInt();
    return SosLocationResult(
      latitude: (source['latitude'] as num?)?.toDouble(),
      longitude: (source['longitude'] as num?)?.toDouble(),
      accuracyMeters: (source['accuracyMeters'] as num?)?.toDouble(),
      source: source['source'] as String? ?? 'unavailable',
      capturedAt: capturedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(capturedAtMillis),
      errorCode: source['errorCode'] as String?,
    );
  }
}
