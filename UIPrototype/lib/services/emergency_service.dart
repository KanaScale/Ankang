import '../models/base_response.dart';
import '../models/emergency_contact_model.dart';
import '../models/emergency_dispatch_attempt_model.dart';
import '../models/emergency_event_model.dart';
import '../models/nearby_hospital_model.dart';
import 'api_client.dart';

class EmergencyService {
  EmergencyService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<List<EmergencyContactModel>>> getContacts() {
    return _apiClient.get<List<EmergencyContactModel>>(
      '/emergency/contacts',
      parser: (json) => ((json as List<dynamic>?) ?? [])
          .map(EmergencyContactModel.fromJson)
          .toList(),
    );
  }

  Future<BaseResponse<EmergencyContactModel>> saveContact(
    EmergencyContactModel contact,
  ) {
    return _apiClient.post<EmergencyContactModel>(
      '/emergency/contacts',
      data: contact.toJson(),
      parser: EmergencyContactModel.fromJson,
    );
  }

  Future<BaseResponse<EmergencyContactModel>> createContact(
    EmergencyContactModel contact,
  ) {
    return saveContact(contact);
  }

  Future<BaseResponse<EmergencyEventModel>> createSosEvent({
    double? latitude,
    double? longitude,
    String? address,
    String? message,
    String? clientEventId,
    DateTime? triggeredAt,
    double? accuracyMeters,
    String? locationSource,
  }) {
    return _apiClient.post<EmergencyEventModel>(
      '/emergency/sos',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'message': message,
        'clientEventId': clientEventId,
        'triggeredAt': triggeredAt?.toIso8601String(),
        'accuracyMeters': accuracyMeters,
        'locationSource': locationSource,
      },
      parser: EmergencyEventModel.fromJson,
    );
  }

  Future<BaseResponse<EmergencyEventModel>> updateDispatchResults(
    String clientEventId,
    List<EmergencyDispatchAttemptModel> attempts,
  ) {
    return _apiClient.put<EmergencyEventModel>(
      '/emergency/events/$clientEventId/dispatch-results',
      data: {'attempts': attempts.map((item) => item.toJson()).toList()},
      parser: EmergencyEventModel.fromJson,
    );
  }

  Future<BaseResponse<List<NearbyHospitalModel>>> getNearbyHospitals({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) {
    return _apiClient.get<List<NearbyHospitalModel>>(
      '/emergency/nearby-hospitals',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      },
      parser: (json) {
        final data = json as Map<String, dynamic>? ?? {};
        return ((data['hospitals'] as List<dynamic>?) ?? [])
            .map(NearbyHospitalModel.fromJson)
            .toList();
      },
    );
  }

  Future<BaseResponse<EmergencyContactModel>> updateContact(
    EmergencyContactModel contact,
  ) {
    return _apiClient.put<EmergencyContactModel>(
      '/emergency/contacts/${contact.id}',
      data: contact.toJson(),
      parser: EmergencyContactModel.fromJson,
    );
  }

  Future<BaseResponse<List<EmergencyEventModel>>> getEvents() {
    return _apiClient.get<List<EmergencyEventModel>>(
      '/emergency/events',
      parser: (json) => ((json as List<dynamic>?) ?? [])
          .map(EmergencyEventModel.fromJson)
          .toList(),
    );
  }

  Future<BaseResponse<void>> deleteContact(int id) {
    return _apiClient.delete<void>('/emergency/contacts/$id');
  }
}
