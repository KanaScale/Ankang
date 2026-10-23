import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/device_sync_model.dart';
import 'package:ankang_assistant/models/emergency_contact_model.dart';
import 'package:ankang_assistant/models/family_models.dart';
import 'package:ankang_assistant/models/health_record_model.dart';
import 'package:ankang_assistant/models/reminder_model.dart';
import 'package:ankang_assistant/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BaseResponse', () {
    test('parses standard backend response', () {
      final response = BaseResponse<UserModel>.fromJson(
        {
          'code': 200,
          'message': 'ok',
          'data': {
            'id': 7,
            'username': 'elder_user',
            'nickname': '王阿姨',
          },
        },
        UserModel.fromJson,
      );

      expect(response.success, isTrue);
      expect(response.code, 200);
      expect(response.data?.id, 7);
      expect(response.data?.nickname, '王阿姨');
    });

    test('parses paged result with records field', () {
      final page = PageResult<HealthRecordModel>.fromJson(
        {
          'records': [
            {
              'id': 1,
              'type': 'bloodSugar',
              'value': 6.4,
              'unit': 'mmol/L',
              'recordedAt': '2026-07-06T08:30:00',
            },
          ],
          'total': 1,
          'current': 1,
          'size': 20,
        },
        HealthRecordModel.fromJson,
      );

      expect(page.items, hasLength(1));
      expect(page.total, 1);
      expect(page.items.first.type, HealthRecordType.bloodSugar);
      expect(page.items.first.value, 6.4);
    });
  });

  group('Business models', () {
    test('parses login result token and user', () {
      final result = LoginResult.fromJson({
        'accessToken': 'jwt-token',
        'user': {'id': 3, 'username': 'test'},
      });

      expect(result.token, 'jwt-token');
      expect(result.user?.username, 'test');
      expect(result.user?.role, 'PATIENT');
    });

    test('parses family invite and bound patient', () {
      final invite = FamilyInviteModel.fromJson({
        'inviteCode': 'A7K92Q',
        'expireAt': '2026-07-24 20:30:00',
      });
      final patient = BoundPatientModel.fromJson({
        'patientUserId': 1,
        'patientName': '张三',
        'relationType': 'father',
        'status': 'ACTIVE',
        'riskLevel': 'medium',
        'permissions': ['VIEW_HEALTH', 'ASK_AGENT'],
      });

      expect(invite.inviteCode, 'A7K92Q');
      expect(invite.expireAt?.hour, 20);
      expect(patient.patientUserId, 1);
      expect(patient.permissions, contains('ASK_AGENT'));
    });

    test('parses reminder enums and enabled flag', () {
      final reminder = ReminderModel.fromJson({
        'id': 2,
        'title': '测血压',
        'type': 'bloodPressure',
        'remindAt': '2026-07-06T20:00:00',
        'repeatType': 'daily',
        'enabled': false,
      });

      expect(reminder.type, ReminderType.bloodPressure);
      expect(reminder.repeatType, ReminderRepeatType.daily);
      expect(reminder.enabled, isFalse);
    });

    test('parses emergency contact', () {
      final contact = EmergencyContactModel.fromJson({
        'id': 5,
        'name': '家属',
        'phone': '13800138000',
        'relationship': '子女',
        'priority': 1,
      });

      expect(contact.name, '家属');
      expect(contact.phone, '13800138000');
      expect(contact.priority, 1);
    });

    test('parses device sync written health records', () {
      final sync = DeviceSyncModel.fromJson({
        'id': 6,
        'deviceName': 'Mock Band',
        'metrics': [
          {
            'type': 'heart_rate',
            'label': 'Heart rate',
            'value': 132,
            'unit': 'bpm',
            'status': 'warning',
          },
        ],
        'writtenRecordIds': [88, '89'],
        'writtenRecordTypes': ['heart_rate', 'blood_pressure'],
        'riskAlert': {
          'eventId': 'device-risk-88',
          'healthRecordId': 88,
          'status': 'completed',
          'riskLevel': 'elevated',
          'riskScore': 40,
          'summary': 'Heart rate is high',
        },
      });

      expect(sync.writtenRecordIds, [88, 89]);
      expect(sync.writtenRecordTypes, ['heart_rate', 'blood_pressure']);
      expect(sync.metrics.first.status, 'warning');
      expect(sync.riskAlert?.healthRecordId, 88);
      expect(sync.riskAlert?.needsAttention, isTrue);
    });
  });
}
