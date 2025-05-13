import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
    this.isRead = false,
  });

  // Create from FCM RemoteMessage
  factory NotificationModel.fromRemoteMessage(RemoteMessage message) {
    return NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      data: message.data,
      timestamp: message.sentTime ?? DateTime.now(),
    );
  }

  // Create from JSON (for SharedPreferences storage)
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] ?? {},
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      isRead: json['isRead'] ?? false,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
    };
  }

  // Create a copy with modified fields
  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
