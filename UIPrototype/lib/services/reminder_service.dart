import '../models/base_response.dart';
import '../models/reminder_model.dart';
import 'api_client.dart';

class ReminderService {
  ReminderService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<List<ReminderModel>>> getReminders() {
    return _apiClient.get<List<ReminderModel>>(
      '/reminders',
      parser: (json) =>
          ((json as List<dynamic>?) ?? []).map(ReminderModel.fromJson).toList(),
    );
  }

  Future<BaseResponse<ReminderModel>> saveReminder(ReminderModel reminder) {
    return _apiClient.post<ReminderModel>(
      '/reminders',
      data: reminder.toJson(),
      parser: ReminderModel.fromJson,
    );
  }

  /// 更新提醒的全部可编辑字段，包括快捷启停操作。
  Future<BaseResponse<ReminderModel>> updateReminder(ReminderModel reminder) {
    return _apiClient.put<ReminderModel>(
      '/reminders/${reminder.id}',
      data: reminder.toJson(),
      parser: ReminderModel.fromJson,
    );
  }

  /// 标记当前提醒周期已完成；周期语义由后端统一计算。
  Future<BaseResponse<void>> completeReminder(int id) {
    return _apiClient.put<void>('/reminders/$id/complete');
  }

  /// 取消当前周期完成状态，让提醒重新进入今日待办。
  Future<BaseResponse<void>> uncompleteReminder(int id) {
    return _apiClient.put<void>('/reminders/$id/uncomplete');
  }

  Future<BaseResponse<void>> deleteReminder(int id) {
    return _apiClient.delete<void>('/reminders/$id');
  }
}
