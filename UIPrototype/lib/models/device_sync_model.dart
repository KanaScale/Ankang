import 'health_event_model.dart';

class DeviceMetricModel {
  const DeviceMetricModel({
    required this.type,
    required this.label,
    this.value,
    this.systolic,
    this.diastolic,
    this.unit,
    this.status = 'normal',
  });

  final String type;
  final String label;
  final double? value;
  final int? systolic;
  final int? diastolic;
  final String? unit;
  final String status;

  String get displayValue {
    if (type == 'blood_pressure' && systolic != null && diastolic != null) {
      return '$systolic/$diastolic ${unit ?? 'mmHg'}';
    }
    if (value == null) {
      return '--';
    }
    final number = value == value!.roundToDouble()
        ? value!.toStringAsFixed(0)
        : value!.toStringAsFixed(1);
    return '$number ${unit ?? ''}'.trim();
  }

  factory DeviceMetricModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return DeviceMetricModel(
      type: json['type'] as String? ?? 'other',
      label: json['label'] as String? ?? '指标',
      value: _asDouble(json['value']),
      systolic: _asInt(json['systolic']),
      diastolic: _asInt(json['diastolic']),
      unit: json['unit'] as String?,
      status: json['status'] as String? ?? 'normal',
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class DeviceSignalModel {
  const DeviceSignalModel({
    required this.signalId,
    required this.signalType,
    required this.status,
    required this.message,
    required this.sentAt,
  });

  final String signalId;
  final String signalType;
  final String status;
  final String message;
  final DateTime sentAt;

  factory DeviceSignalModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return DeviceSignalModel(
      signalId: json['signalId'] as String? ?? '--',
      signalType: json['signalType'] as String? ?? 'ping',
      status: json['status'] as String? ?? 'sent',
      message: json['message'] as String? ?? '模拟信号已发送',
      sentAt: _asDateTime(json['sentAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value.replaceFirst(' ', 'T'));
    }
    return null;
  }
}

class DeviceSyncModel {
  const DeviceSyncModel({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.provider,
    required this.bindStatus,
    required this.connectionStatus,
    required this.battery,
    required this.metrics,
    this.writtenRecordIds = const [],
    this.writtenRecordTypes = const [],
    this.riskAlert,
    this.lastSyncAt,
    this.lastSignal,
  });

  final int id;
  final String deviceName;
  final String deviceType;
  final String provider;
  final String bindStatus;
  final String connectionStatus;
  final int battery;
  final DateTime? lastSyncAt;
  final List<DeviceMetricModel> metrics;
  final DeviceSignalModel? lastSignal;
  final List<int> writtenRecordIds;
  final List<String> writtenRecordTypes;
  final HealthEventModel? riskAlert;

  factory DeviceSyncModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    final rawMetrics = json['metrics'] as List<dynamic>? ?? const [];
    return DeviceSyncModel(
      id: DeviceMetricModel._asInt(json['id']) ?? 0,
      deviceName: json['deviceName'] as String? ?? '安康模拟手环',
      deviceType: json['deviceType'] as String? ?? 'wearable',
      provider: json['provider'] as String? ?? 'mock',
      bindStatus: json['bindStatus'] as String? ?? 'active',
      connectionStatus: json['connectionStatus'] as String? ?? 'online',
      battery: DeviceMetricModel._asInt(json['battery']) ?? 76,
      lastSyncAt: DeviceSignalModel._asDateTime(json['lastSyncAt']),
      metrics: rawMetrics.map(DeviceMetricModel.fromJson).toList(),
      lastSignal: json['lastSignal'] == null
          ? null
          : DeviceSignalModel.fromJson(json['lastSignal']),
      writtenRecordIds: _asIntList(json['writtenRecordIds']),
      writtenRecordTypes: _asStringList(json['writtenRecordTypes']),
      riskAlert: json['riskAlert'] == null
          ? null
          : HealthEventModel.fromJson(json['riskAlert']),
    );
  }

  static List<int> _asIntList(Object? source) {
    final items = source as List<dynamic>? ?? const [];
    return items
        .map(DeviceMetricModel._asInt)
        .whereType<int>()
        .toList(growable: false);
  }

  static List<String> _asStringList(Object? source) {
    final items = source as List<dynamic>? ?? const [];
    return items.map((item) => item.toString()).toList(growable: false);
  }
}
