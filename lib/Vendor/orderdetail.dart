import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../services/send_service.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late String orderId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    orderId = ModalRoute.of(context)!.settings.arguments as String;
  }

  Future<void> completeOrder(
    String orderId, List<Map<String, dynamic>> orderItems) async {
    final firestore = FirebaseFirestore.instance;

    // customer id/ vendor_id
    final orderDoc = await firestore.collection('orders').doc(orderId).get();
      final orderData = orderDoc.data();
      if (orderData == null) {
        throw Exception('Order not found');
      }
    final customerUid = orderData['uid'];
    final vendorVid = orderData['vendor_id'];

    // mealid/ quantity/ status
    for (final item in orderItems) {
      final mealRef = firestore.collection('meals').doc(item['meal_id']);
      final mealSnap = await mealRef.get();
      final mealData = mealSnap.data();

      if (mealData != null) {
      final currentQty = mealData['quantity_available'] ?? 0;
      final orderedQty = item['quantity'];

      final updatedQty = (currentQty - orderedQty) < 0 ? 0 : currentQty - orderedQty;
      final updatedStatus = updatedQty <= 0 ? false : mealData['status'];

      await mealRef.update({
        'quantity_available': updatedQty,
        'status': updatedStatus,
        });
      }
    }

    await firestore.collection('orders').doc(orderId).update({
      'status': 'confirmed',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order marked as confirmed')),
    );

    // final customerDoc = await FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(customerUid)
    //     .get();

    // final customerToken = customerDoc.data()?['fcm_token'];

    // // Send notification
    // if (customerToken != null) {
    //   // 2. Send notification
    //   await SendService.sendNotification(
    //     fcmToken: customerToken,
    //     title: 'Order Complete',
    //     body: 'Your food is ready!',
    //     data: {
    //       'order_id': orderId,
    //       'type': 'order_complete',
    //     },
    //   );
    // }

    // store notification (order complete)
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': 'Order Complete',
      'body': 'Your food is ready!',
      'sender_id': vendorVid,
      'receiver_id': customerUid,
      'sent_at': Timestamp.now(),
      'seen': false,
    });

    // Save to revenue collection
    double totalRevenue = 0.0;
    for (var item in orderItems) {
      totalRevenue += item['quantity'] * item['price'];
    }

    // store notification (revenue added)
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': 'Revenue Added',
      'body': 'RM ${totalRevenue.toStringAsFixed(2)} has been added to your revenue.',
      'sender_id': vendorVid,
      'receiver_id': vendorVid,
      'sent_at': Timestamp.now(),
      'seen': false,
    });

    await FirebaseFirestore.instance.collection('revenue').add({
      'order_id': orderId,
      'sender_id': customerUid,
      'receiver_id': vendorVid,
      'revenue': totalRevenue,
      'created_at': Timestamp.now(),
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details'),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: firestore.collection('orders').doc(orderId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final order = snapshot.data!.data() as Map<String, dynamic>;
          final orderTime = (order['order_time'] as Timestamp).toDate();
          final status = order['status'];

          return FutureBuilder<QuerySnapshot>(
            future: firestore
                .collection('order_items')
                .where('order_id', isEqualTo: orderId)
                .get(),
            builder: (context, itemSnap) {
              if (!itemSnap.hasData) return const Center(child: CircularProgressIndicator());

              final itemDocs = itemSnap.data!.docs;
              List<Map<String, dynamic>> orderItems = [];

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: Future.wait(itemDocs.map((doc) async {
                  final item = doc.data() as Map<String, dynamic>;
                  final mealSnap = await firestore
                      .collection('meals')
                      .doc(item['meal_id'])
                      .get();
                  final mealData = mealSnap.data()!;
                  final quantity = item['quantity'];
                  final price = mealData['price'];
                  final total = quantity * price;

                  final map = {
                    'meal_id': item['meal_id'],
                    'image_URL': mealData['image_URL'],
                    'name': mealData['name'],
                    'price': price,
                    'quantity': quantity,
                    'total': total,
                  };
                  orderItems.add(map);
                  return map;
                })),
                builder: (context, mealsSnapshot) {
                  if (!mealsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: ORDER DATE | STATUS | ORDER ID
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _metaColumn('ORDER DATE', "${orderTime.toLocal()}".split(' ')[0]),
                              Expanded(
                                child: Center(
                                  child: _metaColumn('ORDER ID', orderId, center: true),
                                ),
                              ),
                              _metaColumn('STATUS', status),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Meal List Section
                          for (final item in orderItems)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item['image_URL'],
                                      height: 60,
                                      width: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item['quantity']} × RM ${item['price'].toStringAsFixed(2)}',
                                          style: const TextStyle(color: Colors.black54),
                                        ),
                                        Text(
                                          'Total: RM ${item['total'].toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Complete Button 
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: status == 'pending'
                                  ? () => completeOrder(orderId, orderItems)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.green,
                              ),
                              child: const Text('Complete Order',
                                  style: TextStyle(color: Colors.white)),
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

  Widget _metaColumn(String label, String value, {bool center = false}) {
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 10, color: Colors.grey, letterSpacing: 0.5),
          textAlign: center ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: center ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
  }

}
