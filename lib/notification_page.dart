import 'package:flutter/material.dart';
import 'global_app_bar.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  AppUser? currentUser;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadNotifications();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.instance.getCurrentUserData();
    if (mounted) {
      setState(() {
        currentUser = user;
      });
    }
  }

  void _loadNotifications() {
    // Sample notifications - replace with actual data from your backend
    notifications = [
      {
        'id': '1',
        'title': 'New Order Received',
        'body': 'You have a new order from customer John Doe',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
        'type': 'order',
        'read': false,
      },
      {
        'id': '2',
        'title': 'Delivery Completed',
        'body': 'Your delivery to Downtown was completed successfully',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'type': 'delivery',
        'read': true,
      },
      {
        'id': '3',
        'title': 'Payment Received',
        'body': 'Payment of \$25.50 has been received',
        'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
        'type': 'payment',
        'read': false,
      },
    ];
  }

  void _markAsRead(String notificationId) {
    setState(() {
      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        notifications[index]['read'] = true;
      }
    });
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag;
      case 'delivery':
        return Icons.local_shipping;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'order':
        return Colors.orange;
      case 'delivery':
        return Colors.blue;
      case 'payment':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        currentUser: currentUser,
        title: 'Notifications',
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isRead = notification['read'] as bool;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isRead ? 1 : 3,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: _getNotificationColor(notification['type']),
                      child: Icon(
                        _getNotificationIcon(notification['type']),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      notification['title'],
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: isRead ? Colors.grey[600] : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notification['body'],
                          style: TextStyle(
                            color: isRead ? Colors.grey[500] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTimestamp(notification['timestamp']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                    trailing: !isRead
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                    onTap: () {
                      if (!isRead) {
                        _markAsRead(notification['id']);
                      }
                      // Handle notification tap - navigate to relevant page
                    },
                  ),
                );
              },
            ),
    );
  }
}
