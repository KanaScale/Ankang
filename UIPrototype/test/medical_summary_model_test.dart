import 'package:flutter_test/flutter_test.dart';
import 'package:ankang_assistant/models/medical_summary_model.dart';

void main() {
  test('parses structured medical summary response', () {
    final summary = MedicalSummaryModel.fromJson({
      'generatedAt': '2026-07-28T10:00:00',
      'rangeStart': '2026-07-15',
      'rangeEnd': '2026-07-28',
      'rangeDays': 14,
      'patient': {
        'displayName': 'Sophia',
        'age': 62,
        'gender': 'female',
      },
      'healthProfile': {
        'height': 165,
        'weight': 60,
        'bmi': 22.04,
        'chronicDiseases': ['高血压'],
        'allergies': '青霉素',
      },
      'metrics': [
        {
          'type': 'blood_pressure',
          'label': '血压',
          'unit': 'mmHg',
          'recordCount': 3,
          'latestValue': '145/92',
          'latestAt': '2026-07-28T09:00:00',
          'averageValue': '138/86',
          'minimumValue': '128/80',
          'maximumValue': '145/92',
          'abnormalCount': 1,
          'latestStatus': 'warning',
        }
      ],
      'riskEvents': [],
      'medication': {
        'enabledCount': 1,
        'completedCurrentCycleCount': 1,
        'reminders': [
          {
            'title': '降压药',
            'schedule': '2026-07-28 08:00',
            'repeatType': 'daily',
            'completedCurrentCycle': true,
          }
        ],
      },
      'dataSources': [
        {
          'source': 'smart_band',
          'label': '智能手环',
          'recordCount': 2,
        }
      ],
      'totalRecordCount': 3,
      'abnormalRecordCount': 1,
      'disclaimer': '仅用于就医沟通',
    });

    expect(summary.patient.displayName, 'Sophia');
    expect(summary.healthProfile.chronicDiseases, ['高血压']);
    expect(summary.metrics.single.latestValue, '145/92');
    expect(summary.medication.reminders.single.completedCurrentCycle, isTrue);
    expect(summary.dataSources.single.label, '智能手环');
    expect(summary.abnormalRecordCount, 1);
  });
}
