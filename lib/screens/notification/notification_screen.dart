import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spark_aquanix_delivery/backend/models/notification_model.dart';
import 'package:spark_aquanix_delivery/backend/providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();

    // Refresh notifications when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false)
          .refreshNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Mark all as read',
            onPressed: () async {
              await Provider.of<NotificationProvider>(context, listen: false)
                  .markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('All notifications marked as read')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear all',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Notifications'),
                  content: const Text(
                      'Are you sure you want to clear all notifications?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Provider.of<NotificationProvider>(context,
                                listen: false)
                            .clearAllNotifications();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('All notifications cleared')),
                        );
                      },
                      child: const Text('CLEAR'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, _) {
          if (notificationProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = notificationProvider.notifications;

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await notificationProvider.refreshNotifications();
            },
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationItem(context, notification);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(
      BuildContext context, NotificationModel notification) {
    final DateFormat formatter = DateFormat('MMM d, h:mm a');
    final String formattedDate = formatter.format(notification.timestamp);
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) async {
        await notificationProvider.removeNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification removed')),
        );
      },
      child: InkWell(
        onTap: () async {
          // Mark as read when tapped
          if (!notification.isRead) {
            await notificationProvider.markAsRead(notification.id);
          }

          // Handle navigation or action based on notification data
          _handleNotificationTap(context, notification);
        },
        child: Container(
          color: notification.isRead ? null : Colors.blue.withOpacity(0.1),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: notification.isRead ? Colors.grey : Colors.blue,
              child: const Icon(
                Icons.notifications,
                color: Colors.white,
              ),
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight:
                    notification.isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.body),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            trailing: !notification.isRead
                ? IconButton(
                    icon:
                        const Icon(Icons.circle, size: 12, color: Colors.blue),
                    onPressed: () async {
                      await notificationProvider.markAsRead(notification.id);
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(
      BuildContext context, NotificationModel notification) {
    // You can add navigation logic here based on the notification data
    // For example, if it's a chat message, navigate to the chat screen
    // if (notification.data['type'] == 'chat') {
    //   Navigator.of(context).push(
    //     MaterialPageRoute(
    //       builder: (context) => ChatScreen(chatId: notification.data['chatId']),
    //     ),
    //   );
    // }

    // For now, just show a toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notification opened: ${notification.title}')),
    );
  }
}
