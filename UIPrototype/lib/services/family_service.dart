import '../models/agent_chat_model.dart';
import '../models/agent_action.dart';
import '../models/base_response.dart';
import '../models/emergency_event_model.dart';
import '../models/family_models.dart';
import '../models/health_record_model.dart';
import '../models/reminder_model.dart';
import 'api_client.dart';

class FamilyService {
  FamilyService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<FamilyInviteModel>> createInvite() {
    return _apiClient.post<FamilyInviteModel>(
      '/family/invite',
      parser: FamilyInviteModel.fromJson,
    );
  }

  Future<BaseResponse<BoundPatientModel>> bindPatient({
    required String inviteCode,
    String relationType = 'other',
  }) {
    return _apiClient.post<BoundPatientModel>(
      '/family/bind',
      data: {
        'inviteCode': inviteCode,
        'relationType': relationType,
      },
      parser: BoundPatientModel.fromJson,
    );
  }

  Future<BaseResponse<List<BoundPatientModel>>> getBoundPatients() {
    return _apiClient.get<List<BoundPatientModel>>(
      '/family/patients',
      parser: (json) => ((json as List<dynamic>?) ?? [])
          .map(BoundPatientModel.fromJson)
          .where((item) => item.patientUserId > 0)
          .toList(),
    );
  }

  Future<BaseResponse<void>> unbindPatient(int patientId) {
    return _apiClient.delete<void>('/family/patients/$patientId');
  }

  Future<BaseResponse<FamilyHealthSummaryModel>> getFamilyHealthSummary(
    int patientId,
  ) {
    return _apiClient.get<FamilyHealthSummaryModel>(
      '/family/patients/$patientId/summary',
      parser: FamilyHealthSummaryModel.fromJson,
    );
  }

  Future<BaseResponse<PageResult<HealthRecordModel>>> getFamilyHealthRecords({
    required int patientId,
    int page = 1,
    int pageSize = 20,
    HealthRecordType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _apiClient.get<PageResult<HealthRecordModel>>(
      '/family/patients/$patientId/records',
      queryParameters: {
        'page': page,
        'size': pageSize,
        if (type != null) 'type': type.apiValue,
        if (startDate != null) 'startDate': _dateOnly(startDate),
        if (endDate != null) 'endDate': _dateOnly(endDate),
      },
      parser: (json) => PageResult<HealthRecordModel>.fromJson(
        json as Map<String, dynamic>? ?? const {},
        HealthRecordModel.fromJson,
      ),
    );
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<BaseResponse<HealthTrendSummary>> getFamilyHealthTrend({
    required int patientId,
    required HealthRecordType type,
    String range = '7d',
    int? days,
  }) {
    return _apiClient.get<HealthTrendSummary>(
      '/family/patients/$patientId/trend',
      queryParameters: {
        'type': type.apiValue,
        if (days != null) 'days': days,
        if (days == null) 'range': range,
      },
      parser: HealthTrendSummary.fromJson,
    );
  }

  Future<BaseResponse<List<ReminderModel>>> getFamilyReminders(int patientId) {
    return _apiClient.get<List<ReminderModel>>(
      '/family/patients/$patientId/reminders',
      parser: (json) =>
          ((json as List<dynamic>?) ?? []).map(ReminderModel.fromJson).toList(),
    );
  }

  Future<BaseResponse<List<EmergencyEventModel>>> getFamilySosEvents(
    int patientId,
  ) {
    return _apiClient.get<List<EmergencyEventModel>>(
      '/family/patients/$patientId/sos-events',
      parser: (json) => ((json as List<dynamic>?) ?? [])
          .map(EmergencyEventModel.fromJson)
          .toList(),
    );
  }

  Future<BaseResponse<AgentReplyModel>> familyAgentChat({
    required int patientId,
    required String message,
    int? sessionId,
  }) {
    return _apiClient.post<AgentReplyModel>(
      '/family/patients/$patientId/agent/chat',
      data: {
        'sessionId': sessionId,
        'message': message,
      },
      parser: AgentReplyModel.fromJson,
    );
  }

  Future<BaseResponse<AgentActionModel>> confirmAgentAction({
    required String actionId,
    required bool confirmed,
  }) {
    return _apiClient.post<AgentActionModel>(
      '/agent/actions/confirm',
      data: {
        'actionId': actionId,
        'confirmed': confirmed,
      },
      parser: AgentActionModel.fromJson,
    );
  }
}
