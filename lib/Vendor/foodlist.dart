import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/meal_model.dart';
import '../global_app_bar.dart';

class FoodListPage extends StatefulWidget {
  const FoodListPage({super.key});

  @override
  State<FoodListPage> createState() => _FoodListPageState();
}

class _FoodListPageState extends State<FoodListPage> {
  Future<List<Meal>> _fetchMealsByCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    

    final snapshot = await FirebaseFirestore.instance
        .collection('meals')
        .where('vendor_id', isEqualTo: currentUser.uid)
        .get();

    return snapshot.docs
        .map((doc) => Meal.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(
        
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                "Food List",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Meal>>(
              future: _fetchMealsByCurrentUser(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final meals = snapshot.data!;
                return Column(
                  children: [
                    Expanded(
                      child: meals.isEmpty
                          ? const Center(child: Text("No meals found."))
                          : ListView.builder(
                              itemCount: meals.length,
                              itemBuilder: (context, index) {
                                final meal = meals[index];
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).pushNamed(
                                      '/fooddetail',
                                      arguments: meal,
                                    ).then((_) => setState(() {}));
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          // Image
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              meal.imageUrl,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.broken_image),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Name and Price
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  meal.name,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  "RM${meal.price.toStringAsFixed(2)}",
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
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
                    // Add New Meal Card
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
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
                              Navigator.of(context)
                                  .pushNamed('/addfood')
                                  .then((_) => setState(() {}));
                            } else {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Verification Required"),
                                  content: const Text(
                                    "You must complete and verify your food safety certifications before adding food.",
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
                          },
                          child: SizedBox(
                            height: 60,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.add_circle, color: Colors.blue, size: 30),
                                  SizedBox(width: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

