import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// A page where users can write or edit a review for their order,
/// and also see the items they purchased, with meal names.
class CustomerReviewPage extends StatefulWidget {
  final String orderId;

  const CustomerReviewPage({Key? key, required this.orderId}) : super(key: key);

  @override
  _CustomerReviewPageState createState() => _CustomerReviewPageState();
}

class _CustomerReviewPageState extends State<CustomerReviewPage> {
  final _firestore = FirebaseFirestore.instance;
  final _userId = FirebaseAuth.instance.currentUser!.uid;

  // Review state
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _reviewDocId;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  /// Load any existing review for this order + user.
  Future<void> _loadExistingReview() async {
    try {
      final query = await _firestore
          .collection('review')
          .where('order_id', isEqualTo: widget.orderId)
          .where('user_id', isEqualTo: _userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        _rating = data['rating'] ?? 0;
        _reviewController.text = data['review_text'] ?? '';
        _reviewDocId = doc.id;
      }
    } catch (_) {
      // ignore load errors
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Fetch the items belonging to this order, and resolve meal names.
  Future<List<Map<String, dynamic>>> _fetchOrderItems() async {
    // 1) load order_items
    final qs = await _firestore
        .collection('order_items')
        .where('order_id', isEqualTo: widget.orderId)
        .get();
    final items = qs.docs.map((d) {
      final m = d.data();
      return {
        'meal_id': m['meal_id'] as String,
        'quantity': m['quantity'] as int,
        'subtotal': (m['subtotal'] as num).toDouble(),
      };
    }).toList();

    if (items.isEmpty) return [];

    // 2) fetch meal names in batch
    final mealIds = items.map((i) => i['meal_id'] as String).toSet().toList();
    final mealDocs = await _firestore
        .collection('meals')
        .where(FieldPath.documentId, whereIn: mealIds)
        .get();
    final idToName = {
      for (var doc in mealDocs.docs) doc.id: doc.data()['name'] as String? ?? 'Unknown'
    };

    // 3) merge names into items
    return items.map((i) => {
          'meal_name': idToName[i['meal_id']] ?? 'Unknown',
          'quantity': i['quantity'],
          'subtotal': i['subtotal'],
        }).toList();
  }

  Future<void> _submitReview() async {
    if (_rating == 0 || _reviewController.text.trim().isEmpty) return;
    setState(() => _submitting = true);

    try {
      final data = {
        'order_id': widget.orderId,
        'user_id': _userId,
        'rating': _rating,
        'review_text': _reviewController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      };

      if (_reviewDocId != null) {
        await _firestore.collection('review').doc(_reviewDocId).update(data);
      } else {
        final newDoc = await _firestore.collection('review').add(data);
        _reviewDocId = newDoc.id;
      }

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving review: \$e')),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Review Order')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display Order ID
            Text(
              'Order ID: ${widget.orderId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Display Order Items with names
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchOrderItems(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
                  return const Text('No items found for this order.');
                }
                final items = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...items.map((i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          "• ${i['quantity']} × ${i['meal_name']} = RM${(i['subtotal'] as double).toStringAsFixed(2)}",
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // Rating stars
            const Text('Rating:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: List.generate(5, (idx) {
                final star = idx + 1;
                return IconButton(
                  icon: Icon(star <= _rating ? Icons.star : Icons.star_border),
                  onPressed: () => setState(() => _rating = star),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Review text
            TextField(
              controller: _reviewController,
              decoration: const InputDecoration(
                labelText: 'Write your review',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_submitting || _rating == 0 || _reviewController.text.trim().isEmpty)
                    ? null
                    : _submitReview,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

