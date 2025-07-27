import 'package:cloud_firestore/cloud_firestore.dart';

class Meal {
  final String mealId;
  final String vendorId;
  final String name;
  final String description;
  final String imageUrl;
  final String allergens;
  final double price;
  final int quantityAvailable;
  final bool isOvercooked;
  final bool status;
  final Timestamp dateCreated;
  final Timestamp expiringTime;

  Meal({
    required this.mealId,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.allergens,
    required this.price,
    required this.quantityAvailable,
    required this.isOvercooked,
    required this.status,
    required this.dateCreated,
    required this.expiringTime,
  });

  /// Factory constructor to build a Meal object from Firestore data
  factory Meal.fromFirestore(Map<String, dynamic> data, String id) {
    return Meal(
      mealId: data['meal_id'] ?? id,
      vendorId: data['vendor_id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image_URL'] ?? '',
      allergens: data['allergens'] ?? '',
      price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
      quantityAvailable: data['quantity_available'] ?? 0,
      isOvercooked: data['is_overcooked'] ?? false,
      status: data['status'] ?? false,
      dateCreated: data['date_created'] ?? Timestamp.now(),
      expiringTime: data['expired_date'] ?? Timestamp.now(),
    );
  }

  /// Convert Meal to Firestore-friendly map
  Map<String, dynamic> toMap() {
    return {
      'vendor_id': vendorId,
      'name': name,
      'description': description,
      'image_URL': imageUrl,
      'allergens': allergens,
      'price': price,
      'quantity_available': quantityAvailable,
      'is_overcooked': isOvercooked,
      'status': status,
      'date_created': dateCreated,
      'expired_date': expiringTime,
    };
  }
}
