import '../models/base_response.dart';
import '../models/medical_summary_model.dart';
import 'api_client.dart';

class MedicalSummaryService {
  MedicalSummaryService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<MedicalSummaryModel>> generate({int days = 14}) {
    return _apiClient.get<MedicalSummaryModel>(
      '/medical-summary',
      queryParameters: {'days': days},
      parser: MedicalSummaryModel.fromJson,
    );
  }
}
