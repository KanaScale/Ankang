import 'package:ankang_assistant/models/health_record_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('heart-rate status matches the displayed 60-100 bpm range', () {
    expect(
      HealthRecordStatusRules.evaluate(HealthRecordType.heartRate, 49),
      HealthRecordStatus.danger,
    );
    expect(
      HealthRecordStatusRules.evaluate(HealthRecordType.heartRate, 50),
      HealthRecordStatus.warning,
    );
    expect(
      HealthRecordStatusRules.evaluate(HealthRecordType.heartRate, 60),
      HealthRecordStatus.normal,
    );
    expect(
      HealthRecordStatusRules.evaluate(HealthRecordType.heartRate, 100),
      HealthRecordStatus.normal,
    );
    expect(
      HealthRecordStatusRules.evaluate(HealthRecordType.heartRate, 101),
      HealthRecordStatus.warning,
    );
    expect(
      HealthRecordStatusRules.evaluate(HealthRecordType.heartRate, 121),
      HealthRecordStatus.danger,
    );
  });

  test('blood glucose and pressure follow their displayed ranges', () {
    expect(
      HealthRecordStatusRules.evaluate(HealthRecordType.bloodSugar, 6.1),
      HealthRecordStatus.normal,
    );
    expect(
      HealthRecordStatusRules.evaluate(HealthRecordType.bloodSugar, 6.2),
      HealthRecordStatus.warning,
    );
    expect(
      HealthRecordStatusRules.evaluate(
        HealthRecordType.bloodPressure,
        85,
        systolic: 85,
        diastolic: 55,
      ),
      HealthRecordStatus.warning,
    );
    expect(
      HealthRecordStatusRules.evaluate(
        HealthRecordType.bloodPressure,
        160,
        systolic: 160,
        diastolic: 100,
      ),
      HealthRecordStatus.danger,
    );
  });
}
