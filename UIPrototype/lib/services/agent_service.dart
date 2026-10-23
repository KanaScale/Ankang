import '../models/agent_chat_model.dart';
import '../models/agent_action.dart';
import '../models/base_response.dart';
import 'api_client.dart';

class AgentService {
  AgentService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<BaseResponse<AgentReplyModel>> chat({
    required String message,
    int? sessionId,
  }) {
    return _apiClient.post<AgentReplyModel>(
      '/agent/chat',
      data: {
        'sessionId': sessionId,
        'message': message,
      },
      parser: AgentReplyModel.fromJson,
    );
  }

  // TODO: The backend exposes POST /agent/chat/stream as SSE. Flutter Web
  // needs a POST-capable SSE client before this can replace the stable
  // non-streaming chat fallback used by the current home page.

  Future<BaseResponse<List<AgentSessionModel>>> getSessions() {
    return _apiClient.get<List<AgentSessionModel>>(
      '/agent/sessions',
      parser: (json) => ((json as List<dynamic>?) ?? [])
          .map(AgentSessionModel.fromJson)
          .where((item) => item.id != 0)
          .toList(),
    );
  }

  Future<BaseResponse<List<AgentMessageModel>>> getSessionMessages(
    int sessionId,
  ) {
    return _apiClient.get<List<AgentMessageModel>>(
      '/agent/sessions/$sessionId/messages',
      parser: (json) => ((json as List<dynamic>?) ?? [])
          .map(AgentMessageModel.fromJson)
          .where((item) => item.content.trim().isNotEmpty)
          .toList(),
    );
  }

  Future<BaseResponse<void>> deleteSession(int sessionId) {
    return _apiClient.delete<void>('/agent/sessions/$sessionId');
  }

  Future<BaseResponse<AgentActionModel>> confirmAction({
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
