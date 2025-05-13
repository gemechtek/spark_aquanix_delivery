import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark_aquanix_delivery/backend/models/notification_model.dart';
import 'package:spark_aquanix_delivery/const/app_logger.dart';
import 'package:spark_aquanix_delivery/main.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Keys for SharedPreferences
  static const String _notificationsKey = 'stored_notifications';
  static const String _fcmTokenKey = 'fcm_token';
  static const String _initialOrderIdKey = 'initial_notification_order_id';

  // Store the order ID from initial notification
  static String? initialNotificationOrderId;

  // Stream controller for notifications updates
  static final _notificationsStreamController =
      StreamController<List<NotificationModel>>.broadcast();

  static Stream<List<NotificationModel>> get notificationsStream =>
      _notificationsStreamController.stream;

  /// Initialize notification services
  static Future<void> initialize() async {
    try {
      // Initialize notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Set up foreground notification presentation options
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialize local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          AppLogger.log('Notification tapped: ${response.payload}');
        },
      );

      // Load initial notification order ID
      await _loadInitialOrderId();

      // Set up handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleInitialMessage(initialMessage);
      }
      _messaging.onTokenRefresh.listen(_updateFcmToken);
    } catch (e) {
      AppLogger.log('Error initializing notification service: $e');
    }
  }

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      AppLogger.log('Got a foreground message: ${message.messageId}');
      await _storeNotification(message);

      if (message.notification != null) {
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
        );
        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _localNotifications.show(
          message.hashCode,
          message.notification?.title,
          message.notification?.body,
          notificationDetails,
          payload: message.data['orderId'] ?? message.data.toString(),
        );
      }
    } catch (e) {
      AppLogger.log('Error handling foreground message: $e');
    }
  }

  /// Handle background-opened notifications
  static Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    try {
      AppLogger.log('Notification opened app: ${message.messageId}');
      await _storeNotification(message);
    } catch (e) {
      AppLogger.log('Error handling message opened app: $e');
    }
  }

  /// Handle initial message
  static Future<void> _handleInitialMessage(RemoteMessage message) async {
    try {
      AppLogger.log('App opened from terminated state: ${message.messageId}');
      await _storeNotification(message);
      if (message.data.containsKey('orderId')) {
        initialNotificationOrderId = message.data['orderId'];
        await _saveInitialOrderId(initialNotificationOrderId!);
      }
    } catch (e) {
      AppLogger.log('Error handling initial message: $e');
    }
  }

  /// Store notification
  static Future<void> _storeNotification(RemoteMessage message) async {
    try {
      if (message.notification?.title == null &&
          message.notification?.body == null) {
        return;
      }
      final newNotification = NotificationModel.fromRemoteMessage(message);
      final notifications = await getNotifications();
      if (notifications.any((n) => n.id == newNotification.id)) {
        return;
      }
      notifications.insert(0, newNotification);
      final prefs = await SharedPreferences.getInstance();
      final encodedList =
          jsonEncode(notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_notificationsKey, encodedList);
      _notificationsStreamController.add(notifications);
      AppLogger.log('Notification stored: ${newNotification.title}');
    } catch (e) {
      AppLogger.log('Error storing notification: $e');
    }
  }

  /// Save initial order ID
  static Future<void> _saveInitialOrderId(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_initialOrderIdKey, orderId);
      AppLogger.log('Saved initial order ID: $orderId');
    } catch (e) {
      AppLogger.log('Error saving initial order ID: $e');
    }
  }

  /// Load initial order ID
  static Future<void> _loadInitialOrderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      initialNotificationOrderId = prefs.getString(_initialOrderIdKey);
      if (initialNotificationOrderId != null) {
        AppLogger.log('Loaded initial order ID: $initialNotificationOrderId');
      }
    } catch (e) {
      AppLogger.log('Error loading initial order ID: $e');
    }
  }

  /// Clear initial order ID
  static Future<void> clearInitialOrderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_initialOrderIdKey);
      initialNotificationOrderId = null;
      AppLogger.log('Cleared initial order ID');
    } catch (e) {
      AppLogger.log('Error clearing initial order ID: $e');
    }
  }

  /// Update FCM token
  static Future<void> _updateFcmToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
      AppLogger.log('FCM token updated: $token');
    } catch (e) {
      AppLogger.log('Error updating FCM token: $e');
    }
  }

  /// Get FCM token
  static Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      AppLogger.log('Retrieved FCM token: $token');
      return token;
    } catch (e) {
      AppLogger.log('Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      AppLogger.log('Subscribed to topic: $topic');
    } catch (e) {
      AppLogger.log('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      AppLogger.log('Unsubscribed from topic: $topic');
    } catch (e) {
      AppLogger.log('Error unsubscribing from topic: $e');
    }
  }

  /// Request permissions
  static Future<void> requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      AppLogger.log('Permission status: ${settings.authorizationStatus}');
    } catch (e) {
      AppLogger.log('Error requesting permissions: $e');
    }
  }

  /// Get stored notifications
  static Future<List<NotificationModel>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getString(_notificationsKey);
      if (storedData == null || storedData.isEmpty) {
        return [];
      }
      final decodedList = jsonDecode(storedData) as List<dynamic>;
      return decodedList
          .map((item) => NotificationModel.fromJson(item))
          .toList();
    } catch (e) {
      AppLogger.log('Error getting notifications: $e');
      return [];
    }
  }

  /// Get unread count
  static Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications = notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      final prefs = await SharedPreferences.getInstance();
      final encodedList =
          jsonEncode(updatedNotifications.map((n) => n.toJson()).toList());
      await prefs.setString(_notificationsKey, encodedList);
      _notificationsStreamController.add(updatedNotifications);
      AppLogger.log('Notification marked as read: $notificationId');
    } catch (e) {
      AppLogger.log('Error marking notification as read: $e');
    }
  }

  /// Mark all as read
  static Future<void> markAllAsRead() async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications =
          notifications.map((n) => n.copyWith(isRead: true)).toList();
      final prefs = await SharedPreferences.getInstance();
      final encodedList =
          jsonEncode(updatedNotifications.map((n) => n.toJson()).toList());
      await prefs.setString(_notificationsKey, encodedList);
      _notificationsStreamController.add(updatedNotifications);
      AppLogger.log('All notifications marked as read');
    } catch (e) {
      AppLogger.log('Error marking all notifications as read: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      _notificationsStreamController.add([]);
      AppLogger.log('All notifications cleared');
    } catch (e) {
      AppLogger.log('Error clearing notifications: $e');
    }
  }

  /// Remove specific notification
  static Future<void> removeNotification(String notificationId) async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications =
          notifications.where((n) => n.id != notificationId).toList();
      final prefs = await SharedPreferences.getInstance();
      final encodedList =
          jsonEncode(updatedNotifications.map((n) => n.toJson()).toList());
      await prefs.setString(_notificationsKey, encodedList);
      _notificationsStreamController.add(updatedNotifications);
      AppLogger.log('Notification removed: $notificationId');
    } catch (e) {
      AppLogger.log('Error removing notification: $e');
    }
  }
}
