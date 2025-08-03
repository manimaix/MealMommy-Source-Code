import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Location & delivery
  Position? _customerPosition;
  Position? _vendorPosition;
  double _deliveryFee = 0.0;
  String? _vendorId;

  // Address
  final TextEditingController _addressController = TextEditingController();
  //Discount
  bool _isDiscountApplied = false;
  @override
  void initState() {
    super.initState();
    _fetchMeals();
    _initLocation();
  }

  Future<void> _fetchMeals() async {
  try {
    final querySnapshot = await _firestore.collection('meals').get();
    final now = DateTime.now();
    final docs = querySnapshot.docs;

    _meals = docs.map((doc) {
      final data = doc.data();
      final Timestamp? expiryTs = data['expiring_time'];
      final DateTime? expiryDate = expiryTs?.toDate();

      final bool isAvailable = expiryDate != null &&
          expiryDate.difference(now).inMinutes > 60;

      return {
        'id': doc.id,
        'name': data['name'] ?? 'No Name',
        'description': data['description'] ?? 'No Description',
        'price': (data['price'] ?? 0).toDouble(),
        'imageUrl': data['image_URL'] ?? '',
        'allergens': data['allergens'] ?? '',
        'quantityAvailable': data['quantity_available'] ?? 0,
        'expiringTime': expiryDate,
        'isAvailable': isAvailable,
        'vendor_id': data['vendor_id'] ?? ''
      };
    }).where((meal) => meal['isAvailable'] == true).toList();
  } catch (e) {
    debugPrint('Error fetching meals: $e');
  } finally {
    setState(() => _isLoading = false);
  }
  }

  Future<void> _initLocation() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
    _customerPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    await _getCustomerAddress();

    setState(() {}); // reflect location data
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location permission denied')),
    );
  }
}

  Future<void> _fetchVendorLocation() async {
    try {
      final doc = await _firestore.collection('users').doc(_vendorId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final lat = double.tryParse(data['address_latitude']?.toString() ?? '') ?? 0.0;
      final lng = double.tryParse(data['address_longitude']?.toString() ?? '') ?? 0.0;
      _vendorPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );

      debugPrint('Vendor Position set → $_vendorPosition');
    } catch (e) {
      debugPrint('Error fetching vendor location: $e');
    }
  }

  Future<void> _getCustomerAddress() async {
    try {
      if (_customerPosition == null) return;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        _customerPosition!.latitude,
        _customerPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address =
            '${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.postalCode}, ${place.country}';
        setState(() {         
          _addressController.text = address;
        });
      }
    } catch (e) {
      debugPrint('Failed to get address: $e');
    }
  }

  Future<double> _calculateDeliveryFeeWithDiscount(String vendorId) async {
  if (_customerPosition == null || _vendorPosition == null) return 0.0;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 0.0;

  final metres = Geolocator.distanceBetween(
    _customerPosition!.latitude,
    _customerPosition!.longitude,
    _vendorPosition!.latitude,
    _vendorPosition!.longitude,
  );
  final km = metres / 1000;
  double baseFee = km.ceilToDouble() * 1.0;

  try {
    final twentyMinutesAgo = DateTime.now().subtract(const Duration(minutes: 20));

    final snapshot = await _firestore
        .collection('orders')
        .where('vendor_id', isEqualTo: vendorId)
        .get();

    final recentVendorOrders = snapshot.docs.where((doc) {
      final createdAt = doc.data()['created_at'];
      return createdAt is Timestamp &&
          createdAt.toDate().isAfter(twentyMinutesAgo);
    }).toList();

    _isDiscountApplied = recentVendorOrders.isNotEmpty;

    if (_isDiscountApplied) {
      baseFee *= 0.9;
      debugPrint('Discount applied: 10% off delivery fee for vendor $vendorId');
    }
  } catch (e) {
    debugPrint('Error checking discount Eligibility: $e');
  }

  return baseFee;
}


  void _addToCart(Map<String, dynamic> meal) async {
  if (meal['quantityAvailable'] <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This item is out of stock')),
    );
    return;
  }

  final id = meal['id'] as String;

  // ✅ Set vendor & calculate fee on first item
  if (_cart.isEmpty) {
    _vendorId = meal['vendor_id'];
    await _fetchVendorLocation();
    _deliveryFee = await _calculateDeliveryFeeWithDiscount(_vendorId!);
    setState(() {});
  }

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

  double _calculateItemsTotal() {
    return _cart.values.fold<double>(
      0.0,
      (sum, item) => sum + (item['price'] as double) * (item['quantity'] as int),
    );
  }

  void _showCart() {
  final cartItems = _cart.values.toList();
  final itemsTotal = _calculateItemsTotal();
  final grandTotal = itemsTotal + _deliveryFee;

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
                itemCount: cartItems.length + 2,
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
                        'RM${price.toStringAsFixed(2)} × $qty = RM${(price * qty).toStringAsFixed(2)}',
                      ),
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
                          Navigator.pop(context);
                          _showCart(); // reopen after update
                        },
                      ),
                    );
                  } else if (i == cartItems.length) {
                    // Delivery Fee row
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delivery Fee: RM${_deliveryFee.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_isDiscountApplied)
                            const Text(
                              '(10% off applied)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    );
                  } else {
                    // Grand Total row
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'Grand Total: RM${grandTotal.toStringAsFixed(2)}',
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
  Navigator.of(context).pop();
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final deliveryAddress = _addressController.text.trim();
  if (deliveryAddress.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a delivery address before ordering.')),
    );
    return;
  }

  try {
    final createdAt = Timestamp.now();

    // Group cart items by vendor
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    _cart.forEach((_, item) {
      final vid = item['vendor_id'] as String;
      grouped.putIfAbsent(vid, () => []).add(item);
    });

    for (final entry in grouped.entries) {
      final vendorId = entry.key;
      final items = entry.value;

      // Recalculate delivery fee for this vendor
      _vendorId = vendorId;
      await _fetchVendorLocation();
      _deliveryFee = await _calculateDeliveryFeeWithDiscount(vendorId);

      final itemsTotal = items.fold<double>(
        0,
        (sum, i) => sum + (i['price'] as double) * (i['quantity'] as int),
      );
      final grandTotal = itemsTotal + _deliveryFee;

      final orderId = _firestore.collection('orders').doc().id;
      final orderRef = _firestore.collection('orders').doc(orderId);

      // 1) Create the order
      await orderRef.set({
        'order_id': orderId,
        'created_at': createdAt,
        'customer_id': user.uid,
        'vendor_id': vendorId,
        'runner_id': "",
        'delivery_fee': _deliveryFee,
        'delivery_address': deliveryAddress,
        'latitude': _customerPosition?.latitude ?? 0.0,
        'longitude': _customerPosition?.longitude ?? 0.0,
        'items_total': itemsTotal,
        'grand_total': grandTotal,
        'status': 'pending',
      });

      // 2) Batch write: order_items + stock deduction + revenue
      final batch = _firestore.batch();

      for (var item in items) {
        // a) order_items
        final oiRef = _firestore.collection('order_items').doc();
        batch.set(oiRef, {
          'meal_id': item['id'],
          'order_id': orderId,
          'quantity': item['quantity'],
          'subtotal': (item['price'] as double) * (item['quantity'] as int),
        });

        // b) deduct stock
        final mealRef = _firestore.collection('meals').doc(item['id']);
        batch.update(mealRef, {
          'quantity_available': FieldValue.increment(-(item['quantity'] as int)),
        });
      }

      // c) revenue
      final revRef = _firestore.collection('revenue').doc();
      batch.set(revRef, {
        'created_at': createdAt,
        'order_id': orderId,
        'sender_id': user.uid,
        'receiver_id': vendorId,
        'revenue': itemsTotal,
      });

      await batch.commit();

      // 3) group_orders table
      final groupOrderRef = _firestore.collection('grouporders').doc();
      await groupOrderRef.set({
        'group_order_id': groupOrderRef.id,
        'order_id': orderId,
        'vendor_id': vendorId,
        'driver_id': '',
        'status': 'pending',
        'assigned_at': null,
        'completed_at': null,
        'created_at': createdAt,
      });
    }

    // Refresh available meals
    await _fetchMeals();

    setState(() {
      _cart.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order placed successfully!')),
    );
  } catch (e) {
    debugPrint('Error in checkout: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to place order')),
    );
  }
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
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _addressController,                       
                        decoration: InputDecoration(
                          labelText: 'Delivery Address',
                          prefixIcon: const Icon(Icons.location_on),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
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
                                      placeholder: (ctx, url) =>
                                          const CircularProgressIndicator(),
                                      errorWidget: (ctx, url, err) =>
                                          const Icon(Icons.fastfood),
                                    )
                                  : const Icon(Icons.fastfood),
                              title: Text(meal['name'] as String),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(meal['description'] as String),
                                  Text(
                                      'RM${(meal['price'] as double).toStringAsFixed(2)}'),
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
                    ),
                  ],
                ),
    );
  }
}