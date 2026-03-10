import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:not_test/notification_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background message: ${message.messageId}");
  
  // Save notification locally when in background
  await _saveNotificationLocally(message);
}

// Save notification to SharedPreferences
Future<void> _saveNotificationLocally(RemoteMessage message) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Get saved notifications list
    List<String> savedNotifications = prefs.getStringList('notifications') ?? [];
    
    // Convert notification to JSON with all data
    NotificationItem notificationItem = NotificationItem.fromRemoteMessage(message);
    String notificationJson = jsonEncode(notificationItem.toJson());
    
    // Add new notification at the beginning
    savedNotifications.insert(0, notificationJson);
    
    // Keep only last 50 notifications
    if (savedNotifications.length > 50) {
      savedNotifications = savedNotifications.sublist(0, 50);
    }
    
    await prefs.setStringList('notifications', savedNotifications);
    print('✅ Notification saved locally');
  } catch (e) {
    print('❌ Error saving notification: $e');
  }
}

class NotScreen extends StatefulWidget {
  const NotScreen({super.key});

  @override
  State<NotScreen> createState() => _NotScreenState();
}

class _NotScreenState extends State<NotScreen> {
  List<NotificationItem> notifications = [];
  bool _isLoading = true;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    setupNotifications();
    _loadSavedNotifications();
    
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped - opening app');
      _handleNotificationClick(NotificationItem.fromRemoteMessage(message));
    });
    
    // Check if app was opened from a terminated state
    _checkInitialMessage();
  }

  // Load saved notifications from SharedPreferences
  Future<void> _loadSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedNotifications = prefs.getStringList('notifications') ?? [];
      
      List<NotificationItem> loadedNotifications = [];
      
      for (String notifJson in savedNotifications) {
        try {
          Map<String, dynamic> data = jsonDecode(notifJson);
          loadedNotifications.add(NotificationItem.fromJson(data));
        } catch (e) {
          print('Error parsing saved notification: $e');
        }
      }
      
      setState(() {
        notifications = loadedNotifications;
        _isLoading = false;
      });
      
      print('✅ Loaded ${notifications.length} notifications from local storage');
    } catch (e) {
      print('❌ Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void setupNotifications() async {
    // Android setup
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS setup
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('Local notification tapped: ${response.payload}');
        
        // Handle local notification tap
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            Map<String, dynamic> payload = jsonDecode(response.payload!);
            print('Payload data: $payload');
          } catch (e) {
            print('Error parsing payload: $e');
          }
        }
      },
    );

    // Request permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Get FCM token
    String? token = await FirebaseMessaging.instance.getToken();
    print("🔑 FCM Token: $token");

    // Listen for messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📩 New message while app is open');
      
      // Save notification locally
      await _saveNotificationLocally(message);
      
      // Reload notifications
      await _loadSavedNotifications();

      // Show local notification
      _showLocalNotification(message);
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    if (message.notification != null) {
      // Prepare payload with all data
      String payload = jsonEncode({
        'messageId': message.messageId,
        'data': message.data,
      });

      flutterLocalNotificationsPlugin.show(
        message.hashCode, 
        message.notification!.title,
        message.notification!.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id', 
            'notifications', 
            channelDescription: 'Main notifications channel',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            showWhen: true,
            enableLights: true,
            color: Colors.blue,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload, // Send data as payload
      );
    }
  }

  void _handleNotificationClick(NotificationItem notification) {
    print('Notification data: ${notification.data}');
    
    // Show snackbar with notification info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tapped: ${notification.title ?? 'Notification'}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // TODO: Navigate to specific screen based on data
    // Example:
    // if (notification.data['type'] == 'order') {
    //   Navigator.pushNamed(context, '/order', arguments: notification.data);
    // } else if (notification.data['type'] == 'offer') {
    //   Navigator.pushNamed(context, '/offer', arguments: notification.data);
    // }
  }

  void _checkInitialMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    
    if (initialMessage != null) {
      print('📦 App opened from notification (terminated state)');
      
      // Save notification
      await _saveNotificationLocally(initialMessage);
      
      // Reload notifications
      await _loadSavedNotifications();
      
      // Handle click
      _handleNotificationClick(NotificationItem.fromRemoteMessage(initialMessage));
    }
  }

  // Clear all notifications
  Future<void> _clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notifications');
      
      setState(() {
        notifications.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ All notifications cleared')),
      );
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllNotifications,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "No notifications yet",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(
                            Icons.notifications,
                            color: Colors.blue,
                          ),
                        ),
                        title: Text(
                          notification.title ?? "No title",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(notification.body ?? "No body"),
                        trailing: Text(
                          _formatTime(notification.sentTime),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        onTap: () {
                          _handleNotificationClick(notification);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}