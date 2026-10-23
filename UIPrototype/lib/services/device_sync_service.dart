import '../models/base_response.dart';
import '../models/device_sync_model.dart';
import 'api_client.dart';

class DeviceSyncService {
  DeviceSyncService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<DeviceSyncModel>> getCurrentDevice() {
    return _apiClient.get<DeviceSyncModel>(
      '/devices/current',
      parser: DeviceSyncModel.fromJson,
    );
  }

  Future<BaseResponse<DeviceSyncModel>> mockSync() {
    return _apiClient.post<DeviceSyncModel>(
      '/devices/sync/mock',
      parser: DeviceSyncModel.fromJson,
    );
  }

  Future<BaseResponse<DeviceSyncModel>> customSync({
    double? heartRate,
    int? systolic,
    int? diastolic,
    double? bloodGlucose,
    int? steps,
    double? sleepHours,
  }) {
    return _apiClient.post<DeviceSyncModel>(
      '/devices/sync/custom',
      data: {
        'heartRate': heartRate,
        'systolic': systolic,
        'diastolic': diastolic,
        'bloodGlucose': bloodGlucose,
        'steps': steps,
        'sleepHours': sleepHours,
      },
      parser: DeviceSyncModel.fromJson,
    );
  }

  Future<BaseResponse<DeviceSyncModel>> sendSignal({
    required String signalType,
    String? payload,
  }) {
    return _apiClient.post<DeviceSyncModel>(
      '/devices/signal',
      data: {
        'signalType': signalType,
        'payload': payload,
      },
      parser: DeviceSyncModel.fromJson,
    );
  }
}
