class EmergencyContactModel {
  const EmergencyContactModel({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship,
    this.priority = 0,
    this.phoneE164,
    this.phoneType,
    this.smsCapable = false,
    this.clientContactId,
    this.syncState = ContactSyncState.synced,
  });

  final int id;
  final String name;
  final String phone;
  final String? relationship;
  final int priority;
  final String? phoneE164;
  final String? phoneType;
  final bool smsCapable;
  final String? clientContactId;
  final ContactSyncState syncState;

  factory EmergencyContactModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return EmergencyContactModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relationship: json['relationship'] as String?,
      priority: json['priority'] as int? ?? 0,
      phoneE164: json['phoneE164'] as String?,
      phoneType: json['phoneType'] as String?,
      smsCapable: json['smsCapable'] as bool? ?? false,
      clientContactId: json['clientContactId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientContactId': clientContactId,
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'priority': priority,
        'phoneE164': phoneE164,
        'phoneType': phoneType,
        'smsCapable': smsCapable,
      };

  EmergencyContactModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? relationship,
    int? priority,
    String? phoneE164,
    String? phoneType,
    bool? smsCapable,
    String? clientContactId,
    ContactSyncState? syncState,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      priority: priority ?? this.priority,
      phoneE164: phoneE164 ?? this.phoneE164,
      phoneType: phoneType ?? this.phoneType,
      smsCapable: smsCapable ?? this.smsCapable,
      clientContactId: clientContactId ?? this.clientContactId,
      syncState: syncState ?? this.syncState,
    );
  }
}

enum ContactSyncState { synced, pending, failed }
