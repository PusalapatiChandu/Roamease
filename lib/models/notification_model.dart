enum NotificationCategory {
  network,
  roaming,
  location,
  dataUsage,
  security,
  general,
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime timestamp;
  final bool isRead;
  final String? actionRoute;
  final Map<String, dynamic>? payload;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.actionRoute,
    this.payload,
  });

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationCategory? category,
    DateTime? timestamp,
    bool? isRead,
    String? actionRoute,
    Map<String, dynamic>? payload,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'actionRoute': actionRoute,
      'payload': payload,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    NotificationCategory parsedCategory;
    try {
      parsedCategory = NotificationCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => NotificationCategory.general,
      );
    } catch (_) {
      parsedCategory = NotificationCategory.general;
    }

    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(map['timestamp']);
    } catch (_) {
      parsedTime = DateTime.now();
    }

    return NotificationModel(
      id: docId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      category: parsedCategory,
      timestamp: parsedTime,
      isRead: map['isRead'] ?? false,
      actionRoute: map['actionRoute'],
      payload: map['payload'] != null ? Map<String, dynamic>.from(map['payload']) : null,
    );
  }
}

