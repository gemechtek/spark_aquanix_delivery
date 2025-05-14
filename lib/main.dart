import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Spark Aquanix Delivery',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.grey.shade100,
        ),
        // Define named routes
        initialRoute: '/permission',
        routes: {
          '/permission': (context) => const PermissionHandlerScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/forgotPassword': (context) => const ForgotPasswordScreen(),
          '/orders': (context) => const AppShell(child: OrdersScreen()),
          '/notifications': (context) =>
              const AppShell(child: NotificationsScreen()),
          // Note: OrderDetailsScreen is handled dynamically with push
        },
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (context) => const Center(child: Text('Error 404')),
        ),
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
          // Navigate to OrderDetailsScreen with orderId
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailsScreen(
                order: null, // Order will be fetched dynamically or passed
              ),
              settings: RouteSettings(arguments: pendingOrderId),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/orders');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      AppLogger.log('Error in permission/navigation: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login'); // Fallback to login
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
