import 'package:flutter/material.dart';
import 'global_app_bar.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      _loadNotifications(); // Only load notifications after user is set
    }
  }

  Future<void> _loadNotifications() async {
    if (currentUser == null) return;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiver_id', isEqualTo: currentUser!.uid)
        .get();

    final List<Map<String, dynamic>> fetchedNotifications = querySnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'] ?? '',
        'body': data['body'] ?? '',
        'timestamp': (data['sent_at'] as Timestamp).toDate(),
        'type': data['type'] ?? '',
        'read': data['seen'] ?? false,
      };
    }).toList();

    setState(() {
      notifications = fetchedNotifications;
    });
  }


  void _markAsRead(String notificationId) async {
    final index = notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1 && notifications[index]['read'] == false) {
      setState(() {
        notifications[index]['read'] = true;
      });

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'seen': true});
    }
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
