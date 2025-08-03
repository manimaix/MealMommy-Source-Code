import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderPaymentPendingPage extends StatefulWidget {
  const OrderPaymentPendingPage({super.key});

  @override
  State<OrderPaymentPendingPage> createState() => _OrderPaymentPendingPageState();
}

class _OrderPaymentPendingPageState extends State<OrderPaymentPendingPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<List<QueryDocumentSnapshot>> getPendingPayments() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final snapshot = await firestore
        .collection('payment_collection')
        .where('status', isEqualTo: 'pending')
        .where('vendor_id', isEqualTo: currentUser.uid)
        .get();

    return snapshot.docs;
  }


  Future<void> verifyPaymentAndMove(String paymentPendingId) async {
    final paymentDoc = await firestore.collection('payment_collection').doc(paymentPendingId).get();
    if (!paymentDoc.exists) return;

    final data = paymentDoc.data();
    if (data == null || data['status'] != 'pending') return;

    final orderData = data['order'] as Map<String, dynamic>;
    final items = List<Map<String, dynamic>>.from(data['order_items']);
    final vendorId = data['vendor_id'];
    final customerId = data['customer_id'];

    // 1. Update status to complete
    await firestore.collection('payment_collection').doc(paymentPendingId).update({
      'status': 'complete',
      
    });

  final customerDoc = await firestore.collection('users').doc(customerId).get();
    if (!customerDoc.exists) return;

    final customerdata = customerDoc.data();
    if (customerdata == null) return;

    final customername = customerdata['name'];
    final customerphone = customerdata['phone_number'];

    // 3. Create order document
    await firestore.collection('orders').doc(orderData['order_id']).set({
      'order_id': orderData['order_id'],
      'vendor_id': vendorId,
      'customer_id': customerId,
      'customer_name': customername,
      'customer_phone': customerphone,
      'delivery_address': orderData['delivery_address'],
      'delivery_fee': orderData['delivery_fee'],
      'delivery_latitude': orderData['delivery_latitude'],
      'delivery_longitude': orderData['delivery_longitude'],
      'delivery_time': orderData['delivery_time'],
      'pickup_time': orderData['pickup_time'],
      'group_id': orderData['group_id'],
      'total_amount': orderData['total_amount'],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    // 4. Add order items
    for (final item in items) {
      await firestore.collection('order_items').add({
        'order_id': orderData['order_id'],
        'meal_id': item['meal_id'],
        'quantity': item['quantity'],
        'subtotal': item['subtotal'],
      });
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order verified and stored.')));
  }

  Future<String> getCustomerName(String customerId) async {
    final userDoc = await firestore.collection('users').doc(customerId).get();
    return userDoc.exists ? userDoc['name'] ?? 'Unknown' : 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Pending Payments"),
        centerTitle: true,
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: getPendingPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data!;
          if (docs.isEmpty) {
            return const Center(child: Text("No pending payments found."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final order = doc['order'] as Map<String, dynamic>;
              final customerId = doc['customer_id'];

              return FutureBuilder<String>(
                future: getCustomerName(customerId),
                builder: (context, nameSnapshot) {
                  final customerName = nameSnapshot.data ?? 'Loading...';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order ID: ${order['order_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Customer: $customerName'),
                          Text('Total: RM ${order['total_amount']}'),
                          const SizedBox(height: 12),
                          Center(
                            child: ElevatedButton(
                              onPressed: () async {
                                await verifyPaymentAndMove(doc.id);
                              },
                              child: const Text("Verify & Store Order"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
