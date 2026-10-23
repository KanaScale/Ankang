class AgentActionModel {
  const AgentActionModel({
    required this.actionId,
    required this.actionType,
    this.title = '',
    this.description = '',
    this.requiresConfirmation = true,
    this.status = '',
    this.payload = const {},
    this.resultMessage = '',
    this.result = const {},
  });

  final String actionId;
  final String actionType;
  final String title;
  final String description;
  final bool requiresConfirmation;
  final String status;
  final Map<String, dynamic> payload;
  final String resultMessage;
  final Map<String, dynamic> result;

  bool get pending => status == 'PENDING_CONFIRMATION';
  AgentRiskModel? get risk => AgentRiskModel.fromMaybe(result['risk']);
  List<AgentHospitalModel> get nearbyHospitals =>
      AgentHospitalModel.listFrom(result['nearbyHospitals']);
  List<AgentContactModel> get familyContacts =>
      AgentContactModel.listFrom(result['familyContacts']);
  List<AgentContactModel> get emergencyContacts =>
      AgentContactModel.listFrom(result['emergencyContacts']);

  factory AgentActionModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? const {};
    return AgentActionModel(
      actionId: json['actionId'] as String? ?? '',
      actionType: json['actionType'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? true,
      status: json['status'] as String? ?? '',
      payload: _map(json['payload']),
      resultMessage: json['resultMessage'] as String? ?? '',
      result: _map(json['result']),
    );
  }
}

class AgentRiskModel {
  const AgentRiskModel({
    required this.riskLevel,
    required this.riskScore,
    required this.summary,
    this.reasons = const [],
    this.suggestions = const [],
  });

  final String riskLevel;
  final int riskScore;
  final String summary;
  final List<String> reasons;
  final List<String> suggestions;

  static AgentRiskModel? fromMaybe(Object? source) {
    if (source is! Map<String, dynamic>) return null;
    return AgentRiskModel(
      riskLevel: source['riskLevel'] as String? ?? 'unknown',
      riskScore: _int(source['riskScore']) ?? 0,
      summary: source['summary'] as String? ?? '',
      reasons: _stringList(source['reasons']),
      suggestions: _stringList(source['suggestions']),
    );
  }
}

class AgentHospitalModel {
  const AgentHospitalModel({
    required this.name,
    this.address = '',
    this.distance = '',
    this.phone,
  });

  final String name;
  final String address;
  final String distance;
  final String? phone;

  static List<AgentHospitalModel> listFrom(Object? source) {
    return ((source as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => AgentHospitalModel(
            name: json['name'] as String? ?? '',
            address: json['address'] as String? ?? '',
            distance: json['distance'] as String? ?? '',
            phone: json['phone'] as String?,
          ),
        )
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
  }
}

class AgentContactModel {
  const AgentContactModel({
    required this.name,
    this.phone = '',
    this.relationship = '',
  });

  final String name;
  final String phone;
  final String relationship;

  static List<AgentContactModel> listFrom(Object? source) {
    return ((source as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => AgentContactModel(
            name: json['name'] as String? ?? '',
            phone: json['phone'] as String? ?? '',
            relationship: json['relationship'] as String? ??
                json['relation'] as String? ??
                json['relationType'] as String? ??
                '',
          ),
        )
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _stringList(Object? value) {
  return ((value as List<dynamic>?) ?? const [])
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList();
}
