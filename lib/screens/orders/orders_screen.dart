import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spark_aquanix_delivery/backend/enums/order_status.dart';
import 'package:spark_aquanix_delivery/backend/models/order_model.dart';
import 'package:spark_aquanix_delivery/backend/providers/auth_provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/notification_provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/order_provider.dart';
import 'package:spark_aquanix_delivery/screens/auth/login.dart';
import 'package:spark_aquanix_delivery/screens/notification/notification_screen.dart';
import 'package:spark_aquanix_delivery/screens/orders/list_view/order_list_view.dart';
import 'package:spark_aquanix_delivery/screens/orders/widgets/notification_badge.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.deliveryPersonnel != null) {
        // Start listening to orders to keep provider state in sync (optional)
        Provider.of<OrderProvider>(context, listen: false)
            .listenToOrders(authProvider.deliveryPersonnel!.id);
      }
      Provider.of<NotificationProvider>(context, listen: false)
          .refreshNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.deliveryPersonnel != null) {
      // Re-listen to orders to refresh provider state
      Provider.of<OrderProvider>(context, listen: false)
          .listenToOrders(authProvider.deliveryPersonnel!.id);
    }
    await Provider.of<NotificationProvider>(context, listen: false)
        .refreshNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.deliveryPersonnel == null) {
      return const Center(child: Text('Please log in to view orders'));
    }

    final deliveryPersonId = authProvider.deliveryPersonnel!.id;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('My Deliveries'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) {
              return NotificationBadge(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NotificationsScreen())),
                child: const Icon(Icons.notifications),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
          ],
        ),
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
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _onRefresh(context),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Ongoing Orders Tab
            StreamBuilder<List<OrderDetails>>(
              stream: Provider.of<OrderProvider>(context, listen: false)
                  .streamOrders(deliveryPersonId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final orders = snapshot.data ?? [];
                final ongoingOrders = orders
                    .where((order) => order.status != OrderStatus.delivered)
                    .toList();

                if (ongoingOrders.isEmpty) {
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
                          'No ongoing orders',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return OrdersListView(orders: ongoingOrders);
              },
            ),
            // Completed Orders Tab
            StreamBuilder<List<OrderDetails>>(
              stream: Provider.of<OrderProvider>(context, listen: false)
                  .streamOrders(deliveryPersonId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final orders = snapshot.data ?? [];
                final completedOrders = orders
                    .where((order) => order.status == OrderStatus.delivered)
                    .toList();

                if (completedOrders.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No completed orders',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return OrdersListView(orders: completedOrders);
              },
            ),
          ],
        ),
      ),
    );
  }
}
