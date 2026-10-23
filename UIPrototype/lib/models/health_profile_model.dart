class HealthProfileModel {
  const HealthProfileModel({
    this.height,
    this.weight,
    this.bmi,
    this.chronicDiseases = const [],
    this.allergies,
    this.medicalHistory,
    this.device,
  });

  final double? height;
  final double? weight;
  final double? bmi;
  final List<String> chronicDiseases;
  final String? allergies;
  final String? medicalHistory;
  final String? device;

  factory HealthProfileModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return HealthProfileModel(
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      chronicDiseases: ((json['chronicDiseases'] as List<dynamic>?) ?? [])
          .map((item) => item.toString())
          .toList(),
      allergies: json['allergies'] as String?,
      medicalHistory: json['medicalHistory'] as String?,
      device: json['device'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'height': height,
        'weight': weight,
        'chronicDiseases': chronicDiseases,
        'allergies': allergies,
        'medicalHistory': medicalHistory,
        'device': device,
      };
}
