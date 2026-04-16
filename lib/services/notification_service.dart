import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notification_item.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background message: ${message.messageId}");
  await NotificationService.saveNotificationLocally(message);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _storageKey = 'notifications';
  static const int _maxNotifications = 50;

  // Stream for notification clicks
  static final StreamController<String?> _onNotificationTap =
      StreamController<String?>.broadcast();
  static Stream<String?> get onNotificationTap => _onNotificationTap.stream;

  static Future<void> initialize() async {
    // 1. Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _onNotificationTap.add(response.payload);
      },
    );

    // Create the channel on the device so Firebase can use it when backgrounded
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidImplementation?.createNotificationChannel(
      AndroidNotificationChannel(
        'high_importance_channel', // Consistent ID for server-side sync
        'High Importance Notifications',
        description: 'Notifications with custom vibration and sound',
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([
          0, // delay
          300, // vibrate
          200,
          300,
          500,
        ]),
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
      ),
    );

    // 2. Request Permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 4. Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📩 Foreground message: ${message.messageId}');
      await saveNotificationLocally(message);
      showLocalNotification(message);
    });
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    if (message.notification == null) return;

    final String payload = jsonEncode({
      'messageId': message.messageId,
      'data': message.data,
    });

    await _localNotifications.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel', // Match the pre-created channel
          'High Importance Notifications',
          channelDescription: 'Notifications with custom vibration and sound',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          enableLights: true,
          vibrationPattern: Int64List.fromList([
            0, // delay
            300, // vibrate
            200,
            300,
            500,
          ]),
          sound: const RawResourceAndroidNotificationSound('notification'),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
          sound: 'notification.wav',
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> saveNotificationLocally(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = prefs.getStringList(_storageKey) ?? [];

      final item = NotificationItem.fromRemoteMessage(message);
      list.insert(0, jsonEncode(item.toJson()));

      if (list.length > _maxNotifications) {
        list = list.sublist(0, _maxNotifications);
      }

      await prefs.setStringList(_storageKey, list);
      print('✅ Notification saved locally');
    } catch (e) {
      print('❌ Error saving notification: $e');
    }
  }

  static Future<List<NotificationItem>> getSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];

      return list
          .map((json) {
            try {
              return NotificationItem.fromJson(jsonDecode(json));
            } catch (e) {
              return null;
            }
          })
          .whereType<NotificationItem>()
          .toList();
    } catch (e) {
      print('❌ Error loading notifications: $e');
      return [];
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  static Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }
}
