import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:spark_aquanix_delivery/backend/enums/order_status.dart';
import 'package:spark_aquanix_delivery/backend/providers/auth_provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/notification_provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/order_provider.dart';
import 'package:spark_aquanix_delivery/screens/notification/notification_screen.dart';
import 'package:spark_aquanix_delivery/screens/orders/widgets/notification_badge.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.deliveryPersonnel != null) {
        Provider.of<OrderProvider>(context, listen: false)
            .fetchOrders(authProvider.deliveryPersonnel!.id);
      }
      Provider.of<NotificationProvider>(context, listen: false)
          .refreshNotifications();
    });
  }

  Future<void> _onRefresh(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.deliveryPersonnel != null) {
      await Provider.of<OrderProvider>(context, listen: false)
          .fetchOrders(authProvider.deliveryPersonnel!.id);
    }
    await Provider.of<NotificationProvider>(context, listen: false)
        .refreshNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('My Deliveries'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) {
              return NotificationBadge(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => NotificationsScreen())),
                child: const Icon(Icons.notifications),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    authProvider.deliveryPersonnel?.name ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authProvider.deliveryPersonnel?.email ?? 'No email',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${authProvider.deliveryPersonnel?.id.substring(0, 8) ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await authProvider.logout();
                Navigator.of(context).pop(); // Close the drawer
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _onRefresh(context),
        child: Consumer<OrderProvider>(
          builder: (context, orderProvider, _) {
            if (orderProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (orderProvider.error != null) {
              return Center(child: Text('Error: ${orderProvider.error}'));
            }

            final orders = orderProvider.orders;

            if (orders.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No orders assigned',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return GestureDetector(
                  onTap: () {
                    context.goNamed(
                      'order-details',
                      pathParameters: {'orderId': order.id!},
                      extra: order,
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #${order.id?.substring(0, 8)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM dd, yyyy')
                                          .format(order.createdAt),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Chip(
                                      label: Text(
                                        order.status.toString().split('.').last,
                                        style: TextStyle(
                                          color: order.status ==
                                                  OrderStatus.cancelled
                                              ? Colors.red
                                              : Colors.green,
                                          fontSize: 12,
                                        ),
                                      ),
                                      backgroundColor:
                                          order.status == OrderStatus.cancelled
                                              ? Colors.red.withOpacity(0.1)
                                              : Colors.green.withOpacity(0.1),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      labelPadding: const EdgeInsets.only(
                                          left: 0, right: 0),
                                    ),
                                    Text(
                                      '\$${order.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
