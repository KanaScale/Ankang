enum HealthRecordType { bloodPressure, bloodSugar, heartRate, weight, other }

enum HealthRecordStatus { normal, warning, danger }

/// 健康记录状态的唯一判定入口，范围应与录入页参考文案和后端规则保持一致。
abstract final class HealthRecordStatusRules {
  static HealthRecordStatus evaluate(
    HealthRecordType type,
    double value, {
    int? systolic,
    int? diastolic,
  }) {
    return switch (type) {
      HealthRecordType.bloodPressure =>
        (systolic ?? 0) >= 160 || (diastolic ?? 0) >= 100
            ? HealthRecordStatus.danger
            : (systolic ?? 0) >= 140 ||
                    (diastolic ?? 0) >= 90 ||
                    (systolic ?? 0) < 90 ||
                    (diastolic ?? 0) < 60
                ? HealthRecordStatus.warning
                : HealthRecordStatus.normal,
      HealthRecordType.bloodSugar => value >= 11.1
          ? HealthRecordStatus.danger
          : value < 3.9 || value > 6.1
              ? HealthRecordStatus.warning
              : HealthRecordStatus.normal,
      HealthRecordType.heartRate => value < 50 || value > 120
          ? HealthRecordStatus.danger
          : value < 60 || value > 100
              ? HealthRecordStatus.warning
              : HealthRecordStatus.normal,
      HealthRecordType.weight => HealthRecordStatus.normal,
      HealthRecordType.other => HealthRecordStatus.normal,
    };
  }
}

class HealthRecordModel {
  const HealthRecordModel({
    required this.id,
    required this.type,
    required this.value,
    required this.recordedAt,
    this.unit,
    this.remark,
    this.systolic,
    this.diastolic,
    this.status = HealthRecordStatus.normal,
  });

  final int id;
  final HealthRecordType type;
  final double value;
  final String? unit;
  final String? remark;
  final DateTime recordedAt;
  final int? systolic;
  final int? diastolic;
  final HealthRecordStatus status;

  String get title => type.label;

  String get displayValue {
    if (type == HealthRecordType.bloodPressure &&
        systolic != null &&
        diastolic != null) {
      return '$systolic/$diastolic ${unit ?? type.defaultUnit}';
    }
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text ${unit ?? type.defaultUnit}';
  }

  factory HealthRecordModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    final type = HealthRecordTypeX.fromApiValue(json['type'] as String?);
    return HealthRecordModel(
      id: _asInt(json['id']) ?? 0,
      type: type,
      value: _asDouble(json['value']) ??
          _asDouble(json['avg']) ??
          _asDouble(json['systolic']) ??
          0,
      unit: json['unit'] as String? ?? type.defaultUnit,
      remark: json['remark'] as String? ?? json['note'] as String?,
      recordedAt: _asDateTime(json['recordedAt'] ?? json['recorded_at']) ??
          DateTime.now(),
      systolic: _asInt(json['systolic']),
      diastolic: _asInt(json['diastolic']),
      status: HealthRecordStatusX.fromApiValue(json['status'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'type': type.apiValue,
      if (type == HealthRecordType.bloodPressure) ...{
        'systolic': systolic,
        'diastolic': diastolic,
      } else
        'value': value,
      'unit': unit ?? type.defaultUnit,
      'recordedAt': recordedAt.toIso8601String(),
      'remark': remark,
    };
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value.replaceFirst(' ', 'T'));
    }
    return null;
  }
}

class HealthTrendPoint {
  const HealthTrendPoint({
    required this.time,
    required this.value,
  });

  final DateTime time;
  final double value;

  factory HealthTrendPoint.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return HealthTrendPoint(
      time: HealthRecordModel._asDateTime(json['time'] ?? json['date']) ??
          DateTime.now(),
      value: HealthRecordModel._asDouble(json['value']) ?? 0,
    );
  }
}

class HealthTrendSummary {
  const HealthTrendSummary({
    required this.type,
    required this.range,
    required this.points,
    required this.avg,
    required this.max,
    required this.min,
    required this.abnormalCount,
  });

  final HealthRecordType type;
  final String range;
  final List<HealthTrendPoint> points;
  final double avg;
  final double max;
  final double min;
  final int abnormalCount;

  factory HealthTrendSummary.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    return HealthTrendSummary(
      type: HealthRecordTypeX.fromApiValue(json['type'] as String?),
      range: json['range'] as String? ?? '7d',
      points: rawPoints.map(HealthTrendPoint.fromJson).toList(),
      avg: HealthRecordModel._asDouble(json['avg']) ?? 0,
      max: HealthRecordModel._asDouble(json['max']) ?? 0,
      min: HealthRecordModel._asDouble(json['min']) ?? 0,
      abnormalCount: HealthRecordModel._asInt(json['abnormalCount']) ?? 0,
    );
  }
}

extension HealthRecordTypeX on HealthRecordType {
  String get apiValue => switch (this) {
        HealthRecordType.bloodPressure => 'blood_pressure',
        HealthRecordType.bloodSugar => 'blood_glucose',
        HealthRecordType.heartRate => 'heart_rate',
        HealthRecordType.weight => 'weight',
        HealthRecordType.other => 'other',
      };

  String get label => switch (this) {
        HealthRecordType.bloodPressure => '血压',
        HealthRecordType.bloodSugar => '血糖',
        HealthRecordType.heartRate => '心率',
        HealthRecordType.weight => '体重',
        HealthRecordType.other => '其他',
      };

  String get defaultUnit => switch (this) {
        HealthRecordType.bloodPressure => 'mmHg',
        HealthRecordType.bloodSugar => 'mmol/L',
        HealthRecordType.heartRate => 'bpm',
        HealthRecordType.weight => 'kg',
        HealthRecordType.other => '',
      };

  static HealthRecordType fromApiValue(String? value) {
    return switch (value) {
      'blood_pressure' || 'bloodPressure' => HealthRecordType.bloodPressure,
      'blood_glucose' ||
      'blood_sugar' ||
      'bloodSugar' =>
        HealthRecordType.bloodSugar,
      'heart_rate' || 'heartRate' => HealthRecordType.heartRate,
      'weight' => HealthRecordType.weight,
      _ => HealthRecordType.other,
    };
  }
}

extension HealthRecordStatusX on HealthRecordStatus {
  String get label => switch (this) {
        HealthRecordStatus.normal => '正常',
        HealthRecordStatus.warning => '偏高/偏低',
        HealthRecordStatus.danger => '需关注',
      };

  static HealthRecordStatus fromApiValue(String? value) {
    return switch (value) {
      'warning' => HealthRecordStatus.warning,
      'danger' => HealthRecordStatus.danger,
      _ => HealthRecordStatus.normal,
    };
  }
}
