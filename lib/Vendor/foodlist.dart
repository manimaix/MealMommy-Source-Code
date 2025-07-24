import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/meal_model.dart';

class FoodListPage extends StatefulWidget {
  const FoodListPage({super.key});

  @override
  State<FoodListPage> createState() => _FoodListPageState();
}

class _FoodListPageState extends State<FoodListPage> {

  Future<List<Meal>> _fetchMealsByCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return [];
    }

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
      appBar: AppBar(
        title: const Text("Food List"),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Meal>>(
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
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              // leading: Image.network(meal.imageUrl,
                              //     width: 50, height: 50, fit: BoxFit.cover),
                              title: Text(meal.name),
                              subtitle: Text("Price: RM${meal.price.toStringAsFixed(2)}"),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(meal.name),
                                    content: Text(meal.imageUrl),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Close"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),

              // ADD NEW MEAL CARD BELOW LIST
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context)
                        .pushNamed('/addfood')
                        .then((_) => setState(() {})); // Refresh list after return
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
    );
  }
}

