enum OrderStatus {
  pending,
  orderConfirmed,
  shipped,
  outForDelivery,
  delivered,
  cancelled;

  @override
  String toString() {
    return switch (this) {
      OrderStatus.pending => 'Pending',
      OrderStatus.orderConfirmed => 'Order Confirmed',
      OrderStatus.shipped => 'Shipped',
      OrderStatus.outForDelivery => 'Out for Delivery',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  String get value => toString();

  static OrderStatus fromString(String value) {
    return switch (value) {
      'Pending' => OrderStatus.pending,
      'Order Confirmed' => OrderStatus.orderConfirmed,
      'Shipped' => OrderStatus.shipped,
      'Out for Delivery' => OrderStatus.outForDelivery,
      'Delivered' => OrderStatus.delivered,
      'Cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.pending, // Default fallback
    };
  }
}
