import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/notification_provider.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final unreadCount = notificationProvider.unreadCount;
        final isLoading = notificationProvider.isLoading;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: widget.onTap,
              child: widget.child,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            if (isLoading)
              const Positioned(
                right: -5,
                top: -5,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
