class HealthGoalModel {
  const HealthGoalModel({
    this.stepsTarget,
    this.stepsNote,
    this.sleepTarget,
    this.sleepNote,
    this.bloodPressureTarget,
    this.bloodPressureNote,
  });

  final String? stepsTarget;
  final String? stepsNote;
  final String? sleepTarget;
  final String? sleepNote;
  final String? bloodPressureTarget;
  final String? bloodPressureNote;

  factory HealthGoalModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return HealthGoalModel(
      stepsTarget: json['stepsTarget'] as String?,
      stepsNote: json['stepsNote'] as String?,
      sleepTarget: json['sleepTarget'] as String?,
      sleepNote: json['sleepNote'] as String?,
      bloodPressureTarget: json['bloodPressureTarget'] as String?,
      bloodPressureNote: json['bloodPressureNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'stepsTarget': stepsTarget,
        'stepsNote': stepsNote,
        'sleepTarget': sleepTarget,
        'sleepNote': sleepNote,
        'bloodPressureTarget': bloodPressureTarget,
        'bloodPressureNote': bloodPressureNote,
      };
}

class HealthGoalProgressModel {
  const HealthGoalProgressModel({
    required this.steps,
    required this.sleep,
    required this.bloodPressure,
  });

  final HealthGoalProgressItemModel steps;
  final HealthGoalProgressItemModel sleep;
  final HealthGoalProgressItemModel bloodPressure;

  factory HealthGoalProgressModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return HealthGoalProgressModel(
      steps: HealthGoalProgressItemModel.fromJson(json['steps']),
      sleep: HealthGoalProgressItemModel.fromJson(json['sleep']),
      bloodPressure: HealthGoalProgressItemModel.fromJson(
        json['bloodPressure'],
      ),
    );
  }
}

class HealthGoalProgressItemModel {
  const HealthGoalProgressItemModel({
    required this.key,
    required this.label,
    required this.targetText,
    required this.currentText,
    required this.unit,
    required this.progress,
    required this.status,
  });

  final String key;
  final String label;
  final String targetText;
  final String currentText;
  final String unit;
  final double progress;
  final String status;

  bool get achieved => progress >= 1;

  factory HealthGoalProgressItemModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return HealthGoalProgressItemModel(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '目标',
      targetText: json['targetText'] as String? ?? '--',
      currentText: json['currentText'] as String? ?? '--',
      unit: json['unit'] as String? ?? '',
      progress: _asDouble(json['progress']).clamp(0, 1).toDouble(),
      status: json['status'] as String? ?? '进行中',
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}
