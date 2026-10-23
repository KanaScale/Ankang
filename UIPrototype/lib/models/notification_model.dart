class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.read = false,
  });

  final int id;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool read;

  factory NotificationModel.fromJson(Object? source) {
    final json = source as Map<String, dynamic>? ?? {};
    return NotificationModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      read: json['read'] as bool? ?? false,
    );
  }
}
