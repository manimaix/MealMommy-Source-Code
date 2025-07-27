import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// A page where users can write or edit a review for their order.
class CustomerReviewPage extends StatefulWidget {
  final String orderId;

  const CustomerReviewPage({Key? key, required this.orderId}) : super(key: key);

  @override
  _CustomerReviewPageState createState() => _CustomerReviewPageState();
}

class _CustomerReviewPageState extends State<CustomerReviewPage> {
  final _firestore = FirebaseFirestore.instance;
  final _userId = FirebaseAuth.instance.currentUser!.uid;
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
    } catch (e) {
      // Ignore load errors
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0 || _reviewController.text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final data = {
        'order_id': widget.orderId,
        'user_id': _userId,
        'rating': _rating,
        'review_text': _reviewController.text,
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
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Order'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: \${widget.orderId}'),
            const SizedBox(height: 16),
            const Text('Rating:'),
            Row(
              children: List.generate(5, (i) => i + 1)
                  .map((star) => IconButton(
                        icon: Icon(
                          star <= _rating ? Icons.star : Icons.star_border,
                        ),
                        onPressed: () => setState(() => _rating = star),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewController,
              decoration: const InputDecoration(
                labelText: 'Write your review',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_submitting || _rating == 0 || _reviewController.text.isEmpty)
                    ? null
                    : _submitReview,
                child: _submitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }
}
