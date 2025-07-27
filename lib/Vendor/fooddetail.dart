import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_model.dart';
import 'package:firebase_auth/firebase_auth.dart';


Future<List<DocumentSnapshot>> getReviewsForMeal(String mealId) async {
  final orderItemQuery = await FirebaseFirestore.instance
      .collection('order_items')
      .where('meal_id', isEqualTo: mealId)
      .get();

  final orderIds = orderItemQuery.docs.map((doc) => doc['order_id']).toSet();

  if (orderIds.isEmpty) return [];

  final reviewQuery = await FirebaseFirestore.instance
      .collection('review')
      .where('order_id', whereIn: orderIds.toList())
      .get();

  return reviewQuery.docs;
}

class FoodDetailPage extends StatefulWidget {
  final Meal meal;
  const FoodDetailPage({super.key, required this.meal});

  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
  
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  Meal? _meal;

  @override
  void initState() {
    super.initState();
    _meal = widget.meal;
  }

  Future<void> _refreshMeal() async {
    final updatedDoc = await FirebaseFirestore.instance
        .collection('meals')
        .doc(widget.meal.mealId)
        .get();
    final updatedMeal = Meal.fromFirestore(updatedDoc.data()!, widget.meal.mealId);

    setState(() {
      _meal = updatedMeal;
    });
  }

  Future<void> _deleteMeal(String mealId) async {
    await FirebaseFirestore.instance.collection('meals').doc(mealId).delete();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_meal == null) return const Center(child: CircularProgressIndicator());
    final meal = _meal!;

    return Scaffold(
      appBar: AppBar(
        title: Text("Food Detail"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(
                  meal.imageUrl,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 20, color: Colors.black),
                      onSelected: (value) async {
                        if (value == 'edit') {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;

                            final snapshot = await FirebaseFirestore.instance
                                .collection('vendor_verify')
                                .where('vendor_id', isEqualTo: user.uid)
                                .limit(1)
                                .get();

                            final isVerified = snapshot.docs.isNotEmpty &&
                                snapshot.docs.first.data()['verified_status'] == true;

                            if (isVerified) {
                              Navigator.pushNamed(context, '/editfood', arguments: meal)
                              .then((result) {
                            if (result == true) {
                              _refreshMeal(); // This updates meal from Firestore
                            }
                          });
                            } else {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Verification Required"),
                                  content: const Text(
                                    "You must complete and verify your food safety certifications before editing food.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => 
                                      Navigator.of(context).pushReplacementNamed('/cert'),
                                      child: const Text("OK"),
                                    )
                                  ],
                                ),
                              );
                            }

                        } else if (value == 'delete') {
                          _deleteMeal(meal.mealId);
                        }
                      },
                      itemBuilder: (BuildContext context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            buildFoodDetail(meal),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text('Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            _buildReviewSection(meal.mealId),
          ],
        ),
      ),
    );
  }


  // Review Star
  Widget buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.orange,
          size: 20,
        );
      }),
    );
  }

  /// Review
  Widget _buildReviewSection(String mealId) {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: getReviewsForMeal(mealId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final reviews = snapshot.data!;
        if (reviews.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No reviews available.'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            final userId = review['user_id'];
            final reviewText = review['review_text'] ?? '';
            final rating = review['rating'] ?? 0;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink(); // Avoid blank placeholder
                }

                final user = userSnapshot.data!;
                final profileImage = user['profile_image'] ?? '';
                final username = user['name'] ?? 'Anonymous';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(profileImage),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      username,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    buildStarRating(rating.toDouble()),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  reviewText,
                                  textAlign: TextAlign.justify,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )

                );
              },
            );
          },
        );
      },
    );
  }

  /// Food Detail
  Widget buildFoodDetail(Meal meal) {
    final allergens = meal.allergens
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  meal.name,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'RM${meal.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Created on ${DateFormat.yMMMd().format(meal.dateCreated.toDate())}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              meal.description,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allergens.isNotEmpty
                ? allergens.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    );
                  }).toList()
                : [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        'No allergens specified',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
          )
        ],
      ),
    );
  }
}
