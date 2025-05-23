import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:spark_aquanix_delivery/backend/enums/order_status.dart';
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
          .map((doc) => OrderDetails.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _error = 'Failed to fetch orders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Stream to fetch orders in real-time
  Stream<List<OrderDetails>> streamOrders(String deliveryPersonId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryPersonId', isEqualTo: deliveryPersonId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderDetails.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Optional: If you want to keep the orders list in sync with the stream for other uses
  void listenToOrders(String deliveryPersonId) {
    _isLoading = true;
    _error = null;
    notifyListeners();

    streamOrders(deliveryPersonId).listen(
      (orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Failed to stream orders: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Update order status
  Future<String?> updateOrderStatus(String orderId, OrderStatus status,
      {String? deliveryPersonnelName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final docSnapshot = await orderRef.get();

      if (!docSnapshot.exists) {
        throw 'Order not found';
      }

      final currentOrder = OrderDetails.fromFirestore(
        docSnapshot.data()!,
        orderId,
      );
      final updates = <String, dynamic>{
        'status': status.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      };
      String? deliveryCode;
      // Generate delivery code when status is outForDelivery
      if (status == OrderStatus.outForDelivery) {
        deliveryCode =
            (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
                .toString();

        updates['deliveryCode'] = deliveryCode;
      }
      final statusHistory = List<StatusChange>.from(currentOrder.statusHistory)
        ..add(StatusChange(
          status: status,
          timestamp: DateTime.now(),
          comment: "",
        ));
      updates['statusHistory'] = statusHistory.map((s) => s.toMap()).toList();

      // Set deliveredBy when status is delivered
      if (status == OrderStatus.delivered && deliveryPersonnelName != null) {
        updates['deliveredBy'] = deliveryPersonnelName;
        // Send notification to user
        final orderDoc = await orderRef.get();
        final order = OrderDetails.fromFirestore(orderDoc.data()!, orderDoc.id);
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
        _orders[index] = OrderDetails.fromFirestore(
          (await orderRef.get()).data()!,
          orderId,
        );
      }
      return deliveryCode;
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
