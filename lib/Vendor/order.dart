import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../global_app_bar.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  int _selectedIndex = 0;
  Future<List<Map<String, dynamic>>> _fetchPendingOrders() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('vendor_id', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    List<Map<String, dynamic>> items = [];

    for (final orderDoc in ordersSnapshot.docs) {
      final groupOrderId = orderDoc.id;

      final orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('order_items')
          .where('order_id', isEqualTo: groupOrderId)
          .get();

      for (final itemDoc in orderItemsSnapshot.docs) {
        final mealId = itemDoc.data()['meal_id'];
        final quantity = itemDoc.data()['quantity'];

        final mealDoc = await FirebaseFirestore.instance
            .collection('meals')
            .doc(mealId)
            .get();

        if (mealDoc.exists) {
          final mealData = mealDoc.data()!;
          items.add({
            'name': mealData['name'],
            'quantity': quantity,
            'order_id': groupOrderId,
          });
        }
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPendingOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text("No pending orders."));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    "Order List",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final item = orders[index];
                    return InkWell(
                      onTap: () {
                        Navigator.of(context)
                            .pushNamed(
                              '/orderdetail',
                              arguments: item['order_id'],
                            )
                            .then((_) => setState(() {}));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Name and Price
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Order #${(index + 1).toString().padLeft(3, '0')}",
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,

                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Quantity
                              Text(
                                "×${item['quantity']}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
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
