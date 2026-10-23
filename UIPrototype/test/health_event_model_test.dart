import 'package:ankang_assistant/models/health_event_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses completed high-risk health event and timeline', () {
    final event = HealthEventModel.fromJson({
      'eventId': 'event-1',
      'eventType': 'HealthRecordCreatedEvent',
      'healthRecordId': 88,
      'status': 'completed',
      'riskLevel': 'high',
      'riskScore': 100,
      'summary': '检测到较高健康风险',
      'reasons': ['血压明显偏高', '心率处于偏快状态'],
      'sosEventId': 9,
      'occurredAt': '2026-07-22 10:30:00',
      'processedAt': '2026-07-22 10:30:02',
      'timeline': [
        {
          'stage': 'received',
          'message': '健康数据已保存',
          'occurredAt': '2026-07-22 10:30:00',
        },
        {
          'stage': 'completed',
          'message': '事件处理闭环完成',
          'occurredAt': '2026-07-22 10:30:02',
        },
      ],
    });

    expect(event.healthRecordId, 88);
    expect(event.riskLevel, HealthRiskLevel.high);
    expect(event.needsAttention, isTrue);
    expect(event.isFinished, isTrue);
    expect(event.reasons, contains('血压明显偏高'));
    expect(event.sosEventId, 9);
    expect(event.timeline, hasLength(2));
    expect(event.timeline.last.stage, 'completed');
  });

  test('normal event does not require feedback', () {
    final event = HealthEventModel.fromJson({
      'eventId': 'event-2',
      'healthRecordId': 89,
      'status': 'completed',
      'riskLevel': 'normal',
      'riskScore': 0,
    });

    expect(event.needsAttention, isFalse);
  });
}
