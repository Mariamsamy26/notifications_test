import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationItem {
  final String? messageId;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? sentTime;

  const NotificationItem({
    this.messageId,
    this.title,
    this.body,
    this.data = const {},
    this.sentTime,
  });

  /// Create from Firebase RemoteMessage
  factory NotificationItem.fromRemoteMessage(RemoteMessage message) {
    return NotificationItem(
      messageId: message.messageId,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      data: Map<String, dynamic>.from(message.data),
      sentTime: message.sentTime,
    );
  }

  /// Create from JSON (local storage / API)
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      messageId: json['messageId'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      sentTime:
          json['sentTime'] != null ? DateTime.tryParse(json['sentTime']) : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'title': title,
      'body': body,
      'data': data,
      'sentTime': sentTime?.toIso8601String(),
    };
  }

  /// Useful for debugging
  @override
  String toString() {
    return 'NotificationItem(messageId: $messageId, title: $title, body: $body, data: $data, sentTime: $sentTime)';
  }

  /// Equality (optional but useful)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationItem &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId;

  @override
  int get hashCode => messageId.hashCode;
}
