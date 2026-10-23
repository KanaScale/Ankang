import '../models/base_response.dart';
import '../models/health_record_model.dart';
import 'api_client.dart';

class RecordService {
  RecordService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<PageResult<HealthRecordModel>>> getRecords({
    int page = 1,
    int pageSize = 20,
    HealthRecordType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _apiClient.get<PageResult<HealthRecordModel>>(
      '/records',
      queryParameters: {
        'page': page,
        'size': pageSize,
        if (type != null) 'type': type.apiValue,
        if (startDate != null) 'startDate': _dateOnly(startDate),
        if (endDate != null) 'endDate': _dateOnly(endDate),
      },
      parser: _parseRecordPage,
    );
  }

  Future<BaseResponse<HealthRecordModel>> createRecord(
    HealthRecordModel record,
  ) {
    return _apiClient.post<HealthRecordModel>(
      '/records',
      data: record.toJson(),
      parser: HealthRecordModel.fromJson,
    );
  }

  Future<BaseResponse<void>> deleteRecord(int id) {
    return _apiClient.delete<void>('/health/records/$id');
  }

  Future<BaseResponse<HealthTrendSummary>> getTrend({
    required HealthRecordType type,
    String range = '7d',
  }) {
    return _apiClient.get<HealthTrendSummary>(
      '/records/trend',
      queryParameters: {
        'type': type.apiValue,
        'range': range,
      },
      parser: HealthTrendSummary.fromJson,
    );
  }

  PageResult<HealthRecordModel> _parseRecordPage(Object? json) {
    final data = json as Map<String, dynamic>? ?? {};
    final rawItems = data['items'] ??
        data['records'] ??
        data['content'] ??
        data['list'] ??
        const [];
    return PageResult<HealthRecordModel>(
      items:
          (rawItems as List<dynamic>).map(HealthRecordModel.fromJson).toList(),
      total: data['total'] as int? ?? rawItems.length,
      page: data['page'] as int? ?? data['current'] as int? ?? 1,
      pageSize: data['pageSize'] as int? ?? data['size'] as int? ?? 20,
    );
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
