import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Top-level function for handling background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      // Skip notification initialization on web platform to avoid service worker issues
      if (kIsWeb) {
        if (kDebugMode) {
          print('Skipping FCM initialization on web platform');
        }
        return;
      }

      // Request permissions (iOS and mobile)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      if (kDebugMode) {
        print('User granted permission: ${settings.authorizationStatus}');
      }

      // Set background message handler (mobile only)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Initialize local notifications (mobile only)
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create notification channel for Android
      await _createNotificationChannel();

      // Foreground messages (mobile only)
      FirebaseMessaging.onMessage.listen((message) {
        if (kDebugMode) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');
        }
        _showLocal(message);
      });

      // Handle notification tap when app is in background/terminated (mobile only)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (kDebugMode) {
          print('A new onMessageOpenedApp event was published!');
        }
        _handleNotificationTap(message);
      });

      // Check for initial message (when app is launched from a notification)
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Get FCM token (mobile only)
      String? token = await _fcm.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }

    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'mealmommy_channel', // id
      'MealMommy Notifications', // title
      description: 'This channel is used for MealMommy notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _showLocal(RemoteMessage message) {
    // Skip local notifications on web
    if (kIsWeb) return;
    
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mealmommy_channel',
          'MealMommy Notifications',
          channelDescription: 'This channel is used for MealMommy notifications.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          sound: 'default.wav',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // Handle local notification tap
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Handling notification tap: ${message.data}');
    }
    // Handle notification tap based on message data
    // You can navigate to specific pages based on message.data
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }
}
