import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:spark_aquanix_delivery/backend/models/order_model.dart';
import 'package:spark_aquanix_delivery/backend/providers/auth_provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/order_provider.dart';
import 'package:spark_aquanix_delivery/backend/services/notification_service.dart';
import 'package:spark_aquanix_delivery/const/app_logger.dart';
import 'package:spark_aquanix_delivery/firebase_options.dart';
import 'package:spark_aquanix_delivery/screens/auth/login.dart';
import 'package:spark_aquanix_delivery/screens/auth/signup.dart';
import 'package:spark_aquanix_delivery/screens/orders/order_details_screen.dart';
import 'package:spark_aquanix_delivery/screens/orders/orders_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  AppLogger.log('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up FCM background handler - this is still needed at startup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notification service
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/permission',
      routes: [
        GoRoute(
          path: '/permission',
          name: 'permission',
          builder: (context, state) => const PermissionHandlerScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/orders',
          name: 'orders',
          builder: (context, state) => const OrdersScreen(),
          routes: [
            GoRoute(
              path: ':orderId',
              name: 'order-details',
              builder: (context, state) {
                final order = state.extra as OrderDetails?;
                return OrderDetailsScreen(order: order);
              },
            ),
          ],
        ),
      ],
      redirect: (context, state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isLoggedIn = authProvider.isLoggedIn;
        final isLoggingIn = state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup';
        final isPermissionScreen = state.matchedLocation == '/permission';

        if (isPermissionScreen) {
          return null; // Let PermissionHandlerScreen handle the initial navigation
        }

        if (!isLoggedIn && !isLoggingIn) {
          return '/login';
        }
        if (isLoggedIn && isLoggingIn) {
          return '/orders';
        }
        return null;
      },
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Spark Aquanix Delivery',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.grey.shade100,
        ),
        routerConfig: router,
      ),
    );
  }
}

class PermissionHandlerScreen extends StatefulWidget {
  const PermissionHandlerScreen({super.key});

  @override
  State<PermissionHandlerScreen> createState() =>
      _PermissionHandlerScreenState();
}

class _PermissionHandlerScreenState extends State<PermissionHandlerScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissionsThenNavigate();
  }

  Future<void> _requestPermissionsThenNavigate() async {
    // Request notification permissions
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    AppLogger.log('User granted permission: ${settings.authorizationStatus}');

    // Check if the user is logged in
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.isLoggedIn;

    if (!mounted) return;

    // Navigate based on login status using go_router
    if (isLoggedIn) {
      context.go('/orders');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
