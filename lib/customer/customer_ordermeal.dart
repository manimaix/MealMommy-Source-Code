import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MealBrowsePage extends StatefulWidget {
  const MealBrowsePage({Key? key}) : super(key: key);

  @override
  State<MealBrowsePage> createState() => _MealBrowsePageState();
}

class _MealBrowsePageState extends State<MealBrowsePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _meals = [];
  final Map<String, Map<String, dynamic>> _cart = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMeals();
  }

  Future<void> _fetchMeals() async {
    try {
      final querySnapshot = await _firestore.collection('meals').get();
      final docs = querySnapshot.docs;
      _meals = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'No Name',
          'description': data['description'] ?? 'No Description',
          'price': (data['price'] ?? 0).toDouble(),
          'imageUrl': data['image_URL'] ?? '',
          'allergens': data['allergens'] ?? '',
          'quantityAvailable': data['quantity_available'] ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching meals: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addToCart(Map<String, dynamic> meal) {
    if (meal['quantityAvailable'] <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item is out of stock')),
      );
      return;
    }

    final id = meal['id'] as String;
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!['quantity'] = (_cart[id]!['quantity'] as int) + 1;
      } else {
        _cart[id] = {...meal, 'quantity': 1};
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${meal['name']} to cart')),
    );
  }

  int _totalItemCount() {
    return _cart.values.fold<int>(
      0,
      (count, item) => count + (item['quantity'] as int),
    );
  }

  double _calculateTotalPrice() {
    return _cart.values.fold<double>(
      0.0,
      (sum, item) =>
          sum + (item['price'] as double) * (item['quantity'] as int),
    );
  }

  void _showCart() {
  final cartItems = _cart.values.toList();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your Cart'),
      content: cartItems.isEmpty
          ? const Text('Your cart is empty')
          : SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: cartItems.length + 1, // +1 for total
                itemBuilder: (context, i) {
                  if (i < cartItems.length) {
                    final item = cartItems[i];
                    final id = item['id'] as String;
                    final qty = item['quantity'] as int;
                    final price = item['price'] as double;
                    return ListTile(
                      leading: (item['imageUrl'] as String).isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item['imageUrl'] as String,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.fastfood),
                      title: Text(item['name'] as String),
                      subtitle: Text(
                        'RM${price.toStringAsFixed(2)} × $qty  =  RM${(price * qty).toStringAsFixed(2)}',
                      ),
                      // NEW: Remove button
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            if (_cart[id]!['quantity'] > 1) {
                              _cart[id]!['quantity'] = qty - 1;
                            } else {
                              _cart.remove(id);
                            }
                          });
                          // Rebuild the dialog to reflect changes
                          Navigator.pop(context);
                          _showCart();
                        },
                      ),
                    );
                  } else {
                    // total row
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'Total: RM${_calculateTotalPrice().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (cartItems.isNotEmpty)
          TextButton(
            onPressed: _checkout,
            child: const Text('Checkout'),
          ),
      ],
    ),
  );
}


  Future<void> _checkout() async {
    Navigator.pop(context);
    // TODO: implement saving order to Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order placed successfully!')),
    );
    setState(() => _cart.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Meals'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _showCart,
              ),
              if (_cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_totalItemCount()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meals.isEmpty
              ? const Center(child: Text('No meals available'))
              : ListView.builder(
                  itemCount: _meals.length,
                  itemBuilder: (context, index) {
                    final meal = _meals[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: (meal['imageUrl'] as String).isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: meal['imageUrl'] as String,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.fastfood),
                              )
                            : const Icon(Icons.fastfood),
                        title: Text(meal['name'] as String),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(meal['description'] as String),
                            Text('RM${(meal['price'] as double).toStringAsFixed(2)}'),
                            if ((meal['allergens'] as String).isNotEmpty)
                              Text('Allergens: ${meal['allergens']}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_shopping_cart),
                          onPressed: () => _addToCart(meal),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}


