class MedicalSummaryModel {
  const MedicalSummaryModel({
    required this.generatedAt,
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeDays,
    required this.patient,
    required this.healthProfile,
    required this.metrics,
    required this.riskEvents,
    required this.medication,
    required this.dataSources,
    required this.totalRecordCount,
    required this.abnormalRecordCount,
    required this.disclaimer,
  });

  final DateTime? generatedAt;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final int rangeDays;
  final MedicalSummaryPatient patient;
  final MedicalSummaryHealthProfile healthProfile;
  final List<MedicalMetricSummary> metrics;
  final List<MedicalRiskEventSummary> riskEvents;
  final MedicalMedicationSummary medication;
  final List<MedicalDataSourceSummary> dataSources;
  final int totalRecordCount;
  final int abnormalRecordCount;
  final String disclaimer;

  factory MedicalSummaryModel.fromJson(Object? source) {
    final json = _map(source);
    return MedicalSummaryModel(
      generatedAt: _date(json['generatedAt']),
      rangeStart: _date(json['rangeStart']),
      rangeEnd: _date(json['rangeEnd']),
      rangeDays: _integer(json['rangeDays']),
      patient: MedicalSummaryPatient.fromJson(json['patient']),
      healthProfile:
          MedicalSummaryHealthProfile.fromJson(json['healthProfile']),
      metrics: _list(json['metrics'])
          .map(MedicalMetricSummary.fromJson)
          .toList(growable: false),
      riskEvents: _list(json['riskEvents'])
          .map(MedicalRiskEventSummary.fromJson)
          .toList(growable: false),
      medication: MedicalMedicationSummary.fromJson(json['medication']),
      dataSources: _list(json['dataSources'])
          .map(MedicalDataSourceSummary.fromJson)
          .toList(growable: false),
      totalRecordCount: _integer(json['totalRecordCount']),
      abnormalRecordCount: _integer(json['abnormalRecordCount']),
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }
}

class MedicalSummaryPatient {
  const MedicalSummaryPatient({
    required this.displayName,
    this.age,
    this.gender,
  });

  final String displayName;
  final int? age;
  final String? gender;

  factory MedicalSummaryPatient.fromJson(Object? source) {
    final json = _map(source);
    return MedicalSummaryPatient(
      displayName: json['displayName']?.toString() ?? '未填写',
      age: _nullableInteger(json['age']),
      gender: json['gender']?.toString(),
    );
  }
}

class MedicalSummaryHealthProfile {
  const MedicalSummaryHealthProfile({
    this.height,
    this.weight,
    this.bmi,
    required this.chronicDiseases,
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

  factory MedicalSummaryHealthProfile.fromJson(Object? source) {
    final json = _map(source);
    return MedicalSummaryHealthProfile(
      height: _decimal(json['height']),
      weight: _decimal(json['weight']),
      bmi: _decimal(json['bmi']),
      chronicDiseases:
          _list(json['chronicDiseases']).map((item) => '$item').toList(),
      allergies: json['allergies']?.toString(),
      medicalHistory: json['medicalHistory']?.toString(),
      device: json['device']?.toString(),
    );
  }
}

class MedicalMetricSummary {
  const MedicalMetricSummary({
    required this.type,
    required this.label,
    required this.unit,
    required this.recordCount,
    required this.latestValue,
    this.latestAt,
    this.averageValue,
    this.minimumValue,
    this.maximumValue,
    required this.abnormalCount,
    required this.latestStatus,
  });

  final String type;
  final String label;
  final String unit;
  final int recordCount;
  final String latestValue;
  final DateTime? latestAt;
  final String? averageValue;
  final String? minimumValue;
  final String? maximumValue;
  final int abnormalCount;
  final String latestStatus;

  factory MedicalMetricSummary.fromJson(Object? source) {
    final json = _map(source);
    return MedicalMetricSummary(
      type: json['type']?.toString() ?? 'other',
      label: json['label']?.toString() ?? '其他',
      unit: json['unit']?.toString() ?? '',
      recordCount: _integer(json['recordCount']),
      latestValue: json['latestValue']?.toString() ?? '--',
      latestAt: _date(json['latestAt']),
      averageValue: json['averageValue']?.toString(),
      minimumValue: json['minimumValue']?.toString(),
      maximumValue: json['maximumValue']?.toString(),
      abnormalCount: _integer(json['abnormalCount']),
      latestStatus: json['latestStatus']?.toString() ?? 'unknown',
    );
  }
}

class MedicalRiskEventSummary {
  const MedicalRiskEventSummary({
    required this.eventId,
    required this.riskLevel,
    required this.riskScore,
    required this.summary,
    required this.reasons,
    this.occurredAt,
  });

  final String eventId;
  final String riskLevel;
  final int riskScore;
  final String summary;
  final List<String> reasons;
  final DateTime? occurredAt;

  factory MedicalRiskEventSummary.fromJson(Object? source) {
    final json = _map(source);
    return MedicalRiskEventSummary(
      eventId: json['eventId']?.toString() ?? '',
      riskLevel: json['riskLevel']?.toString() ?? 'unknown',
      riskScore: _integer(json['riskScore']),
      summary: json['summary']?.toString() ?? '',
      reasons: _list(json['reasons']).map((item) => '$item').toList(),
      occurredAt: _date(json['occurredAt']),
    );
  }
}

class MedicalMedicationSummary {
  const MedicalMedicationSummary({
    required this.enabledCount,
    required this.completedCurrentCycleCount,
    required this.reminders,
  });

  final int enabledCount;
  final int completedCurrentCycleCount;
  final List<MedicalMedicationReminder> reminders;

  factory MedicalMedicationSummary.fromJson(Object? source) {
    final json = _map(source);
    return MedicalMedicationSummary(
      enabledCount: _integer(json['enabledCount']),
      completedCurrentCycleCount: _integer(json['completedCurrentCycleCount']),
      reminders: _list(json['reminders'])
          .map(MedicalMedicationReminder.fromJson)
          .toList(growable: false),
    );
  }
}

class MedicalMedicationReminder {
  const MedicalMedicationReminder({
    required this.title,
    required this.schedule,
    required this.repeatType,
    required this.completedCurrentCycle,
  });

  final String title;
  final String schedule;
  final String repeatType;
  final bool completedCurrentCycle;

  factory MedicalMedicationReminder.fromJson(Object? source) {
    final json = _map(source);
    return MedicalMedicationReminder(
      title: json['title']?.toString() ?? '用药提醒',
      schedule: json['schedule']?.toString() ?? '--',
      repeatType: json['repeatType']?.toString() ?? 'once',
      completedCurrentCycle: json['completedCurrentCycle'] == true,
    );
  }
}

class MedicalDataSourceSummary {
  const MedicalDataSourceSummary({
    required this.source,
    required this.label,
    required this.recordCount,
  });

  final String source;
  final String label;
  final int recordCount;

  factory MedicalDataSourceSummary.fromJson(Object? source) {
    final json = _map(source);
    return MedicalDataSourceSummary(
      source: json['source']?.toString() ?? 'unknown',
      label: json['label']?.toString() ?? '其他来源',
      recordCount: _integer(json['recordCount']),
    );
  }
}

Map<String, dynamic> _map(Object? source) =>
    source is Map<String, dynamic> ? source : const {};

List<dynamic> _list(Object? source) =>
    source is List<dynamic> ? source : const [];

int _integer(Object? value) => _nullableInteger(value) ?? 0;

int? _nullableInteger(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }
  return null;
}
