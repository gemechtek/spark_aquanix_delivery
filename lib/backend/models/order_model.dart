import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  orderConfirmed,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
}

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
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      size: map['size'] ?? '',
      selectedColor: map['selectedColor'] ?? '',
    );
  }
}

class OrderDetails {
  final String? id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double shippingCost;
  final double total;
  final OrderStatus status;
  final String paymentMethod;
  final DeliveryAddress deliveryAddress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? deliveryPersonId; // New field
  final String? deliveryCode; // New field
  final String? deliveredBy; // New field

  OrderDetails({
    this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.shippingCost,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.deliveryAddress,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryPersonId,
    this.deliveryCode,
    this.deliveredBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'shippingCost': shippingCost,
      'total': total,
      'status': status.toString().split('.').last,
      'paymentMethod': paymentMethod,
      'deliveryAddress': deliveryAddress.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deliveryPersonId': deliveryPersonId,
      'deliveryCode': deliveryCode,
      'deliveredBy': deliveredBy,
    };
  }

  factory OrderDetails.fromMap(Map<String, dynamic> map, String id) {
    return OrderDetails(
      id: id,
      userId: map['userId'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      shippingCost: (map['shippingCost'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == 'OrderStatus.${map['status']}',
        orElse: () => OrderStatus.pending,
      ),
      paymentMethod: map['paymentMethod'] ?? '',
      deliveryAddress: DeliveryAddress.fromMap(map['deliveryAddress'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveryPersonId: map['deliveryPersonId'],
      deliveryCode: map['deliveryCode'],
      deliveredBy: map['deliveredBy'],
    );
  }
}
