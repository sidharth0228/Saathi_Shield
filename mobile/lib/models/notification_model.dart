class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String category; // 'SOS', 'TRAVEL', 'COMMUNITY', 'DISASTER'
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic> payload;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    required this.payload,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? payload,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      category: json['category'] ?? 'DISASTER',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: json['is_read'] ?? false,
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'payload': payload,
    };
  }
}
