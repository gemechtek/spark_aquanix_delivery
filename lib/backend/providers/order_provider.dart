import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:spark_aquanix_delivery/backend/services/cloud_message.dart';
import 'dart:convert';

import '../models/order_model.dart';
import '../models/user_model.dart';

class OrderProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _projectId = 'gemechtek-19a37'; // Firebase project ID

  List<OrderDetails> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<OrderDetails> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch orders assigned to the delivery person
  Future<void> fetchOrders(String deliveryPersonId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('deliveryPersonId', isEqualTo: deliveryPersonId)
          .get();
      _orders = snapshot.docs
          .map((doc) => OrderDetails.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _error = 'Failed to fetch orders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus status,
      {String? deliveryPersonnelName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final updates = <String, dynamic>{
        'status': status.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      };

      // Generate delivery code when status is outForDelivery
      if (status == OrderStatus.outForDelivery) {
        final deliveryCode =
            (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
        updates['deliveryCode'] = deliveryCode;
      }

      // Set deliveredBy when status is delivered
      if (status == OrderStatus.delivered && deliveryPersonnelName != null) {
        updates['deliveredBy'] = deliveryPersonnelName;
        // Send notification to user
        final orderDoc = await orderRef.get();
        final order = OrderDetails.fromMap(orderDoc.data()!, orderDoc.id);
        final userDoc =
            await _firestore.collection('users').doc(order.userId).get();
        final user = UserModel.fromMap(userDoc.data()!);
        if (user.fcmToken.isNotEmpty) {
          await sendNotification(
            user.fcmToken,
            'Order Delivered',
            'Your order #${orderId.substring(0, 8)} has been delivered by $deliveryPersonnelName.',
          );
        }
      }

      await orderRef.update(updates);
      final index = _orders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _orders[index] = OrderDetails.fromMap(
          (await orderRef.get()).data()!,
          orderId,
        );
      }
    } catch (e) {
      _error = 'Failed to update order status: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send FCM notification
  Future<void> sendNotification(
      String fcmToken, String title, String body) async {
    if (fcmToken.isEmpty) {
      throw Exception('No FCM token available for this user');
    }

    try {
      // Get OAuth access token for authentication
      final accessToken = await FirebaseCloudMessaging.getAccessToken();

      // Use FCM v1 API

      final response = await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to send notification: $e');
    }
  }
}
