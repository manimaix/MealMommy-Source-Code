import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../global_app_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 2;
  AppUser? _currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _latestOrders = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchLatestOrders();
    NotificationService().init();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.instance.getCurrentUserData();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading user: $e');
    }
  }

 Future<Map<String, dynamic>> _fetchSummaryData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final orderSnap = await FirebaseFirestore.instance
        .collection('orders')
        .where('vendor_id', isEqualTo: uid)
        .where('status', isEqualTo: "pending")
        .get();
    final menuSnap = await FirebaseFirestore.instance
        .collection('meals')
        .where('vendor_id', isEqualTo: uid)
        .where('status', isEqualTo: true)
        .get();
    final certSnap = await FirebaseFirestore.instance
        .collection('vendor_verify')
        .where('vendor_id', isEqualTo: uid)
        .where('verified_status', isEqualTo: true)
        .get();

    return {
      'orderCount': orderSnap.size,
      'menuCount': menuSnap.size,
      'certVerified': certSnap.docs.isNotEmpty,
    };
  }

  Future<void> _fetchLatestOrders() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('vendor_id', isEqualTo: uid)
        .where('status', isEqualTo: "pending")
        .limit(3)
        .get();

    final orders = snap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'status': data['status'] ?? 'pending',
      };
    }).toList();

    setState(() {
      _latestOrders = orders;
    });
  }

  Widget _buildDashboardBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(int index, String orderId, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
        title: Text("Order #${(index + 1).toString().padLeft(3, '0')}"),
        subtitle: Text("Status: $status"),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: ListView(
              children: [
                Text(
                  "Welcome back, ${_currentUser?.name ?? 'Vendor'}!",
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const Text("Ready to serve your customers today?"),
                const SizedBox(height: 20),

                /// Summary Dashboard
                FutureBuilder(
                  future: _fetchSummaryData(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data as Map<String, dynamic>;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDashboardBox("Orders", data['orderCount'].toString(), Colors.orange),
                        _buildDashboardBox("Menu", data['menuCount'].toString(), Colors.blue),
                        _buildDashboardBox("Cert", data['certVerified'] ? "Verified" : "Invalid",
                            data['certVerified'] ? Colors.green : Colors.red),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                /// Latest Orders Preview
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Latest Orders',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_latestOrders.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/order');
                            },
                            child: const Text('More'),
                          ),
                      ],
                    ),
                    if (_latestOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text("No recent orders."),
                      ),

                    const SizedBox(height: 8),

                    ..._latestOrders.asMap().entries.map((entry) {
                      final index = entry.key;
                      final order = entry.value;
                      return _buildOrderCard(index, order['id'], order['status']);
                    }).toList(),
                  ],
                ),
              ],
            ),
          ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Orders"),
            BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: "Food List"),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Menu"),
            BottomNavigationBarItem(icon: Icon(Icons.money), label: "Revenue"),
          ],
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            switch (index) {
              case 0:
                Navigator.of(context).pushReplacementNamed('/order');
                break;
              case 1:
                Navigator.of(context).pushReplacementNamed('/foodList');
                break;
              case 2:
                Navigator.of(context).pushReplacementNamed('/vendor');
                break;
              case 3:
                Navigator.of(context).pushReplacementNamed('/menu');
                break;
              case 4:
                Navigator.of(context).pushReplacementNamed('/revenue');
                break;
            }
          },
        ),
    );
  }
}
