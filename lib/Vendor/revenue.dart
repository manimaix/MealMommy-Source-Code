import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../global_app_bar.dart';

class RevenuePage extends StatefulWidget {
  const RevenuePage({super.key});

  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  int _selectedIndex = 4;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<DocumentSnapshot> _revenueDocs = [];
  bool _loading = true;
  bool _showAll = false;

  double totalIncome = 0.0;

  @override
  void initState() {
    super.initState();
    fetchRevenue();
  }

  Future<void> fetchRevenue() async {
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      currentUser.uid;
    }
    if (currentUser == null) return;

    try {
      final snapshot = await _firestore
          .collection('revenue')
          .where('receiver_id', isEqualTo: currentUser.uid)
          .orderBy('created_at', descending: true)
          .get();

      final docs = snapshot.docs;
      double total = 0;

      for (final doc in docs) {
        final revenue = (doc['revenue'] ?? 0).toDouble();
        total += revenue;
      }

      setState(() {
        _revenueDocs = docs;
        totalIncome = total;
        _loading = false;
      });
    } catch (e) {
      print('Error loading revenue: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_MY', symbol: 'RM ');

    return Scaffold(
      appBar: const GlobalAppBar(),
      body: _loading
    ? const Center(child: CircularProgressIndicator())
    : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                "Income",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
            // Total Income Centered
            Column(
              children: [
                Text(
                  currencyFormatter.format(totalIncome),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Total Income",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Recent Transactions Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Transactions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_showAll && _revenueDocs.length > 3)
                  TextButton(
                    onPressed: () => setState(() => _showAll = true),
                    child: const Text("More"),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Transaction List
            Column(
              children: _buildRevenueList(currencyFormatter),
            ),

            // Collapse Button
            if (_showAll && _revenueDocs.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _showAll = false),
                  child: const Text("Collapse"),
                ),
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

  List<Widget> _buildRevenueList(NumberFormat currencyFormatter) {
    final displayDocs = _showAll ? _revenueDocs : _revenueDocs.take(3).toList();
    

    return displayDocs.map((doc) {
      final revenue = (doc['revenue'] ?? 0).toDouble();
      final orderId = doc['order_id'] ?? 'N/A';
      final createdAt = (doc['created_at'] as Timestamp).toDate();

      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          title: Text("$orderId"),
          subtitle: Text(DateFormat.yMMMd().format(createdAt)),
          trailing: Text("+${revenue.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
        ),
      );
    }).toList();
  }
}
