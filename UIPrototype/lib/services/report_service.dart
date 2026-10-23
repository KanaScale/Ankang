import '../models/base_response.dart';
import 'api_client.dart';

class WeeklyHealthReport {
  const WeeklyHealthReport({
    required this.weekStart,
    required this.weekEnd,
    required this.summary,
    required this.indicators,
  });

  final String weekStart;
  final String weekEnd;
  final String summary;
  final Map<String, dynamic> indicators;

  factory WeeklyHealthReport.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return WeeklyHealthReport(
      weekStart: json['weekStart'] as String? ?? '',
      weekEnd: json['weekEnd'] as String? ?? '',
      summary: json['summary'] as String? ?? '暂无周报摘要',
      indicators: json['indicators'] as Map<String, dynamic>? ?? const {},
    );
  }
}

class ReportService {
  ReportService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<WeeklyHealthReport>> getWeeklyReport({
    DateTime? weekStart,
  }) {
    return _apiClient.get<WeeklyHealthReport>(
      '/reports/weekly',
      queryParameters: {
        if (weekStart != null) 'weekStart': _dateOnly(weekStart),
      },
      parser: WeeklyHealthReport.fromJson,
    );
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
