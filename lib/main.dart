import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:spark_aquanix_delivery/backend/models/order_model.dart';
import 'package:spark_aquanix_delivery/backend/providers/auth_provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/notification_provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/order_provider.dart';
import 'package:spark_aquanix_delivery/backend/services/notification_service.dart';
import 'package:spark_aquanix_delivery/const/app_logger.dart';
import 'package:spark_aquanix_delivery/firebase_options.dart';
import 'package:spark_aquanix_delivery/screens/auth/forgot_password.dart';
import 'package:spark_aquanix_delivery/screens/auth/login.dart';
import 'package:spark_aquanix_delivery/screens/auth/signup.dart';
import 'package:spark_aquanix_delivery/screens/notification/notification_screen.dart';
import 'package:spark_aquanix_delivery/screens/orders/order_details_screen.dart';
import 'package:spark_aquanix_delivery/screens/orders/orders_screen.dart';

// Global navigator keys for root and shell navigation
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

// Firebase background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    AppLogger.log('Handling background message: ${message.messageId}');
  } catch (e) {
    AppLogger.log('Error in background handler: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    AppLogger.log('Error initializing Firebase: $e');
    return;
  }

  // Set up Firebase Messaging background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Notification Service
  try {
    await NotificationService.initialize();
  } catch (e) {
    AppLogger.log('Error initializing NotificationService: $e');
  }

  // Initialize AuthProvider and check login state
  final authProvider = AuthProvider();
  try {
    await authProvider.checkLoginState();
  } catch (e) {
    AppLogger.log('Error checking login state: $e');
  }

  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;

  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider())
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Spark Aquanix Delivery',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.grey.shade100,
        ),
        routerConfig: appRouter,
      ),
    );
  }
}

// AppShell for wrapping main content with navigation (e.g., sidebar or app bar)
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Basic shell with a centered child; can be enhanced with sidebar/app bar
    return Scaffold(
      body: child,
    );
  }
}

// Navigation configuration using GoRouter
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/permission',
  refreshListenable: AuthProvider(),
  debugLogDiagnostics: true,
  errorBuilder: (context, state) => const Center(child: Text('Error 404')),
  redirect: (context, state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.isLoggedIn;
    final isLoggingIn = state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup' ||
        state.matchedLocation == '/forgotPassword';
    final isPermissionScreen = state.matchedLocation == '/permission';

    if (isPermissionScreen) {
      return null;
    }
    if (!isLoggedIn && !isLoggingIn) {
      return '/login';
    }
    if (isLoggedIn && isLoggingIn) {
      return '/orders';
    }
    return null;
  },
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
      path: '/forgotPassword',
      name: 'forgotPassword',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/orders',
          name: 'orders',
          builder: (context, state) => const OrdersScreen(),
          routes: [
            GoRoute(
              path: ':orderId',
              name: 'order-details',
              builder: (context, state) {
                final orderId = state.pathParameters['orderId'];
                final passedOrder = state.extra is OrderDetails
                    ? state.extra as OrderDetails
                    : null;

                if (passedOrder != null) {
                  return OrderDetailsScreen(order: passedOrder);
                }

                // if (orderId != null) {
                //   return FutureBuilder<OrderDetails?>(
                //     future: Provider.of<OrderProvider>(context, listen: false)
                //         .getOrderById(orderId),
                //     builder: (context, snapshot) {
                //       if (snapshot.connectionState == ConnectionState.waiting) {
                //         return const Center(child: CircularProgressIndicator());
                //       } else if (snapshot.hasError) {
                //         return Center(child: Text('Error: ${snapshot.error}'));
                //       } else {
                //         final order = snapshot.data;
                //         return OrderDetailsScreen(order: order!);
                //       }
                //     },
                //   );
                // }

                return const OrderDetailsScreen(order: null);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
      ],
    ),
  ],
);

// Permission Handler Screen
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
    try {
      await NotificationService.requestPermissions();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkLoginState();
      if (!mounted) return;

      final isLoggedIn = authProvider.isLoggedIn;
      final pendingOrderId = NotificationService.initialNotificationOrderId;

      if (isLoggedIn) {
        if (pendingOrderId != null && pendingOrderId.isNotEmpty) {
          await NotificationService.clearInitialOrderId();
          context.pushNamed('order-details',
              pathParameters: {'orderId': pendingOrderId});
        } else {
          context.go('/orders');
        }
      } else {
        context.go('/login');
      }
    } catch (e) {
      AppLogger.log('Error in permission/navigation: $e');
      if (mounted) {
        context.go('/login'); // Fallback to login on error
      }
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
