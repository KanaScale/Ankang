import 'agent_action.dart';

class AgentReplyModel {
  const AgentReplyModel({
    required this.sessionId,
    this.messageId,
    required this.answer,
    this.citations = const [],
    this.suggestions = const [],
    this.pendingAction,
  });

  final int sessionId;
  final int? messageId;
  final String answer;
  final List<AgentCitationModel> citations;
  final List<String> suggestions;
  final AgentActionModel? pendingAction;

  factory AgentReplyModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return AgentReplyModel(
      sessionId: json['sessionId'] as int? ?? 0,
      messageId: json['messageId'] as int?,
      answer: json['answer'] as String? ?? '',
      citations: _citationList(json['citations']),
      suggestions: _stringList(json['suggestions']),
      pendingAction: json['pendingAction'] == null
          ? null
          : AgentActionModel.fromJson(json['pendingAction']),
    );
  }

  static List<AgentCitationModel> _citationList(Object? value) {
    return ((value as List<dynamic>?) ?? [])
        .map(AgentCitationModel.fromJson)
        .where((item) => item.title.trim().isNotEmpty)
        .toList();
  }

  static List<String> _stringList(Object? value) {
    return ((value as List<dynamic>?) ?? [])
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
}

class AgentCitationModel {
  const AgentCitationModel({
    required this.title,
    this.url = '',
    this.source = '',
    this.snippet = '',
  });

  final String title;
  final String url;
  final String source;
  final String snippet;

  factory AgentCitationModel.fromJson(Object? source) {
    if (source is String) {
      return AgentCitationModel(title: source);
    }
    final json = source as Map<String, dynamic>? ?? {};
    return AgentCitationModel(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      source: json['source'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
    );
  }
}

class AgentSessionModel {
  const AgentSessionModel({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final DateTime? updatedAt;

  factory AgentSessionModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return AgentSessionModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '未命名会话',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class AgentMessageModel {
  const AgentMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String role;
  final String content;
  final DateTime? createdAt;

  bool get fromAgent => role != 'user';

  factory AgentMessageModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return AgentMessageModel(
      id: json['id'] as int? ?? 0,
      role: json['role'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}
