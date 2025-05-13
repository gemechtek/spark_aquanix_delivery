import 'dart:async';
import 'package:flutter/material.dart';

import 'package:spark_aquanix_delivery/backend/models/notification_model.dart';
import 'package:spark_aquanix_delivery/backend/services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  StreamSubscription? _notificationSubscription;

  NotificationProvider() {
    _init();
  }

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> _init() async {
    // Load initial notifications
    await refreshNotifications();

    // Listen for notification updates
    _notificationSubscription =
        NotificationService.notificationsStream.listen((_) {
      // When any notification changes, refresh
      refreshNotifications();
    });
  }

  Future<void> refreshNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get notifications
      _notifications = await NotificationService.getNotifications();

      // Calculate unread count
      _unreadCount =
          _notifications.where((notification) => !notification.isRead).length;
    } catch (e) {
      // Handle error
      debugPrint('Error refreshing notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await NotificationService.markAsRead(notificationId);
    await refreshNotifications();
  }

  Future<void> markAllAsRead() async {
    await NotificationService.markAllAsRead();
    await refreshNotifications();
  }

  Future<void> removeNotification(String notificationId) async {
    await NotificationService.removeNotification(notificationId);
    await refreshNotifications();
  }

  Future<void> clearAllNotifications() async {
    await NotificationService.clearAllNotifications();
    await refreshNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
