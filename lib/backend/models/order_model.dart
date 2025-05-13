import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_aquanix_delivery/backend/enums/order_status.dart';

class DeliveryAddress {
  final String fullName;
  final String phoneNumber;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  DeliveryAddress({
    required this.fullName,
    required this.phoneNumber,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
    };
  }

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) {
    return DeliveryAddress(
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      addressLine1: map['addressLine1'] ?? '',
      addressLine2: map['addressLine2'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      postalCode: map['postalCode'] ?? '',
      country: map['country'] ?? '',
    );
  }
}

class StatusChange {
  final OrderStatus status;
  final DateTime timestamp;
  final String? comment;

  StatusChange({
    required this.status,
    required this.timestamp,
    this.comment,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status.toString(),
      'timestamp': Timestamp.fromDate(timestamp),
      'comment': comment,
    };
  }

  factory StatusChange.fromMap(Map<String, dynamic> map) {
    return StatusChange(
      status: OrderStatus.fromString(map['status'] ?? 'Pending'),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      comment: map['comment'],
    );
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final String image;
  final int quantity;
  final double totalPrice;
  final String size;
  final String selectedColor;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.image,
    required this.quantity,
    required this.totalPrice,
    required this.size,
    required this.selectedColor,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'image': image,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'size': size,
      'selectedColor': selectedColor,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      image: map['image'] ?? '',
      quantity: map['quantity'] ?? 0,
      totalPrice: (map['price'] as num?)?.toDouble() ?? 0.0,
      size: map['size'] ?? '',
      selectedColor: map['selectedColor'] ?? '',
    );
  }
}

class OrderDetails {
  final String? id;
  final String userId;
  final String userName;
  final String userFcmToken;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double shippingCost;
  final double total;
  final DeliveryAddress deliveryAddress;
  final String paymentMethod;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<StatusChange> statusHistory;
  final DateTime? estimatedDeliveryDate;
  final String? deliveryPersonId;
  final String? deliveryCode;
  final String? deliveredBy;
  OrderDetails({
    this.id,
    required this.userId,
    required this.userName,
    required this.userFcmToken,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.shippingCost,
    required this.total,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.status = OrderStatus.pending,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<StatusChange>? statusHistory,
    this.estimatedDeliveryDate,
    this.deliveryPersonId,
    this.deliveryCode,
    this.deliveredBy,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        statusHistory = statusHistory ??
            [
              StatusChange(
                status: OrderStatus.pending,
                timestamp: createdAt ?? DateTime.now(),
                comment: 'Order placed',
              )
            ];

  DateTime? getEstimatedDeliveryDate() {
    final confirmedStatusChange = statusHistory.firstWhere(
      (change) => change.status == OrderStatus.orderConfirmed,
      orElse: () => StatusChange(
        status: OrderStatus.pending,
        timestamp: DateTime.now(),
      ),
    );

    if (confirmedStatusChange.status == OrderStatus.orderConfirmed) {
      return confirmedStatusChange.timestamp.add(const Duration(days: 2));
    }

    return null;
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    // Calculate estimated delivery date if not already set
    final DateTime? deliveryDate =
        estimatedDeliveryDate ?? getEstimatedDeliveryDate();

    return {
      'userId': userId,
      'userName': userName,
      'userFcmToken': userFcmToken,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'shippingCost': shippingCost,
      'total': total,
      'deliveryAddress': deliveryAddress.toMap(),
      'paymentMethod': paymentMethod.toString(),
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'statusHistory': statusHistory.map((change) => change.toMap()).toList(),
      'estimatedDeliveryDate':
          deliveryDate != null ? Timestamp.fromDate(deliveryDate) : null,
      'deliveryPersonId': deliveryPersonId,
      'deliveryCode': deliveryCode,
      'deliveredBy': deliveredBy,
    };
  }

  // Create from Firestore document
  factory OrderDetails.fromFirestore(Map<String, dynamic> data, String docId) {
    // Parse status history or create default
    List<StatusChange> statusHistory = [];
    if (data['statusHistory'] != null) {
      statusHistory = (data['statusHistory'] as List<dynamic>)
          .map((item) => StatusChange.fromMap(item))
          .toList();
    } else {
      // Create default history based on current status
      statusHistory = [
        StatusChange(
          status: OrderStatus.fromString(data['status'] ?? 'Pending'),
          timestamp:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          comment: 'Order created',
        ),
      ];
    }

    return OrderDetails(
      id: docId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userFcmToken: data['userFcmToken'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item))
              .toList() ??
          [],
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      tax: (data['tax'] ?? 0.0).toDouble(),
      shippingCost: (data['shippingCost'] ?? 0.0).toDouble(),
      total: (data['total'] ?? 0.0).toDouble(),
      deliveryAddress: DeliveryAddress.fromMap(
          data['deliveryAddress'] as Map<String, dynamic>? ?? {}),
      paymentMethod: data['paymentMethod'],
      status: OrderStatus.fromString(data['status'] ?? 'Pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      statusHistory: statusHistory,
      estimatedDeliveryDate:
          (data['estimatedDeliveryDate'] as Timestamp?)?.toDate(),
      deliveryPersonId: data['deliveryPersonId'],
      deliveryCode: data['deliveryCode'],
      deliveredBy: data['deliveredBy'],
    );
  }

  // Add a new status change
  OrderDetails updateStatus(OrderStatus newStatus, {String? comment}) {
    final updatedHistory = [...statusHistory];

    // Add new status change
    updatedHistory.add(StatusChange(
      status: newStatus,
      timestamp: DateTime.now(),
      comment: comment,
    ));

    // Calculate new estimated delivery date if status is changing to confirmed
    DateTime? newEstimatedDelivery = estimatedDeliveryDate;
    if (newStatus == OrderStatus.orderConfirmed &&
        status != OrderStatus.orderConfirmed) {
      newEstimatedDelivery = DateTime.now().add(const Duration(days: 2));
    }

    return copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
      statusHistory: updatedHistory,
      estimatedDeliveryDate: newEstimatedDelivery,
    );
  }

  OrderDetails copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userFcmToken,
    List<OrderItem>? items,
    double? subtotal,
    double? tax,
    double? shippingCost,
    double? total,
    DeliveryAddress? deliveryAddress,
    String? paymentMethod,
    OrderStatus? status,
    DateTime? updatedAt,
    List<StatusChange>? statusHistory,
    DateTime? estimatedDeliveryDate,
    String? deliveryPersonId,
    String? deliveryCode,
    String? deliveredBy,
  }) {
    return OrderDetails(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userFcmToken: userFcmToken ?? this.userFcmToken,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      shippingCost: shippingCost ?? this.shippingCost,
      total: total ?? this.total,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      statusHistory: statusHistory ?? this.statusHistory,
      estimatedDeliveryDate:
          estimatedDeliveryDate ?? this.estimatedDeliveryDate,
      deliveredBy: deliveredBy ?? this.deliveredBy,
      deliveryCode: deliveryCode ?? this.deliveryCode,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
    );
  }
}
