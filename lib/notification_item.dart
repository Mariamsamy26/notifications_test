
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationItem {
  final String? messageId;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? sentTime;

  NotificationItem({
    this.messageId,
    this.title,
    this.body,
    required this.data,
    this.sentTime,
  });

  factory NotificationItem.fromRemoteMessage(RemoteMessage message) {
    return NotificationItem(
      messageId: message.messageId,
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
      sentTime: message.sentTime,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      messageId: json['messageId'],
      title: json['title'],
      body: json['body'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      sentTime: json['sentTime'] != null ? DateTime.parse(json['sentTime']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'title': title,
      'body': body,
      'data': data,
      'sentTime': sentTime?.toIso8601String(),
    };
  }
}
