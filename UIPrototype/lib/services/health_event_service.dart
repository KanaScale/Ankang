import '../models/base_response.dart';
import '../models/health_event_model.dart';
import 'api_client.dart';

class HealthEventService {
  HealthEventService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<List<HealthEventModel>>> getEvents({int limit = 20}) {
    return _apiClient.get<List<HealthEventModel>>(
      '/health-events',
      queryParameters: {'limit': limit},
      parser: (source) {
        final items = source as List<dynamic>? ?? const [];
        return items.map(HealthEventModel.fromJson).toList(growable: false);
      },
    );
  }

  Future<BaseResponse<HealthEventModel>> getEventDetail(String eventId) {
    return _apiClient.get<HealthEventModel>(
      '/health-events/$eventId',
      parser: HealthEventModel.fromJson,
    );
  }

  /// 健康记录提交后，等待异步编排器完成对应事件。
  /// 超时返回 null，不影响已经成功保存的健康记录。
  Future<HealthEventModel?> waitForRecordEvent(
    int healthRecordId, {
    Duration timeout = const Duration(seconds: 8),
    Duration interval = const Duration(milliseconds: 400),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final response = await getEvents(limit: 30);
      final events = response.data ?? const <HealthEventModel>[];
      for (final event in events) {
        if (event.healthRecordId == healthRecordId && event.isFinished) {
          return event;
        }
      }
      await Future<void>.delayed(interval);
    }
    return null;
  }

  Future<HealthEventModel?> waitForAnyRecordEvent(
    Iterable<int> healthRecordIds, {
    Duration timeout = const Duration(seconds: 8),
    Duration interval = const Duration(milliseconds: 400),
  }) async {
    final ids = healthRecordIds.where((id) => id > 0).toSet();
    if (ids.isEmpty) {
      return null;
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final response = await getEvents(limit: 50);
      final events = response.data ?? const <HealthEventModel>[];
      for (final event in events) {
        if (ids.contains(event.healthRecordId) &&
            event.isFinished &&
            event.needsAttention) {
          return event;
        }
      }
      await Future<void>.delayed(interval);
    }
    return null;
  }
}
