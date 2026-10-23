class NearbyHospitalModel {
  const NearbyHospitalModel({
    required this.poiId,
    required this.name,
    required this.address,
    required this.distance,
    required this.source,
    this.distanceMeters,
    this.phone,
    this.latitude,
    this.longitude,
    this.category,
  });

  final String poiId;
  final String name;
  final String address;
  final String distance;
  final int? distanceMeters;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String source;

  factory NearbyHospitalModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return NearbyHospitalModel(
      poiId: json['poiId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      distance: json['distance'] as String? ?? '距离未知',
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      phone: json['phone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: json['category'] as String?,
      source: json['source'] as String? ?? 'unknown',
    );
  }
}
