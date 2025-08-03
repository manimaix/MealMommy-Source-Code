import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import 'customer_review.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  String? _uid;
  bool _loading = true;
  List<DocumentSnapshot> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _uid = user.uid;
          _loading = false;
        });
      });
      _loadOrders();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not logged in")),
        );
      });
    }
  }

  Future<void> _loadOrders() async {
    try {
      final snapshot = await _firestore
        .collection('orders')
        .where('customer_id', isEqualTo: _uid)
        .orderBy('created_at', descending: true)
        .get();

      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _orders = snapshot.docs;
        });
      });
    } catch (e) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading orders: $e")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text("Unable to load user UID.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Orders")),
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: RefreshIndicator(
          onRefresh: _loadOrders,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(10),
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              final orderDoc = _orders[index];
              final order = orderDoc.data() as Map<String, dynamic>;
              final orderId = orderDoc.id;

              final Timestamp? ts = order['created_at'] as Timestamp?;
              final String dateString = ts != null
                ? DateFormat('dd-MM-yyyy HH:mm').format(ts.toDate())
                : '—';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                child: ListTile(
                  title: Text(
                    "Order #${order['orderID']?.toString() ?? orderId.substring(0, 8)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Status: ${order['status'] ?? 'N/A'}"),
                      Text("Time: $dateString"),          
                      Text("Delivery: ${order['delivery_address'] ?? '-'}"),
                      Text("Delivery Fee: RM${order['delivery_fee']?.toString() ?? '0'}"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.rate_review),
                    tooltip: 'Review Order',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerReviewPage(orderId: orderId),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

