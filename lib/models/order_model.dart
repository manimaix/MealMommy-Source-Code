import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String id;
  final String groupId;
  final String customerId;
  final String vendorId;
  final String? driverId;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String deliveryAddress;
  final String deliveryFee;
  final String deliveryLatitude;
  final String deliveryLongitude;
  final Timestamp? deliveryTime;
  final Timestamp? pickupTime;
  final String status;
  final String? customerName;
  final String? customerPhone;

  Order({
    required this.id,
    required this.groupId,
    required this.customerId,
    required this.vendorId,
    this.driverId,
    required this.createdAt,
    required this.updatedAt,
    required this.deliveryAddress,
    required this.deliveryFee,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.deliveryTime,
    this.pickupTime,
    required this.status,
    this.customerName,
    this.customerPhone,
  });

  factory Order.fromFirestore(Map<String, dynamic> data, String id) {
    return Order(
      id: id,
      groupId: data['group_id'] ?? '',
      customerId: data['customer_id'] ?? '',
      vendorId: data['vendor_id'] ?? '',
      driverId: data['driver_id'],
      createdAt: data['created_at'] ?? Timestamp.now(),
      updatedAt: data['updated_at'] ?? Timestamp.now(),
      deliveryAddress: data['delivery_address'] ?? '',
      deliveryFee: data['delivery_fee'] ?? '0.00',
      deliveryLatitude: data['delivery_latitude'] ?? '',
      deliveryLongitude: data['delivery_longitude'] ?? '',
      deliveryTime: data['delivery_time'],
      pickupTime: data['pickup_time'],
      status: data['status'] ?? 'pending',
      customerName: data['customer_name'],
      customerPhone: data['customer_phone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'customer_id': customerId,
      'vendor_id': vendorId,
      'driver_id': driverId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'delivery_address': deliveryAddress,
      'delivery_fee': deliveryFee,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'delivery_time': deliveryTime,
      'pickup_time': pickupTime,
      'status': status,
      'customer_name': customerName,
      'customer_phone': customerPhone,
    };
  }

  Order copyWith({
    String? id,
    String? groupId,
    String? customerId,
    String? vendorId,
    String? driverId,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? deliveryAddress,
    String? deliveryFee,
    String? deliveryLatitude,
    String? deliveryLongitude,
    Timestamp? deliveryTime,
    Timestamp? pickupTime,
    String? status,
    String? customerName,
    String? customerPhone,
  }) {
    return Order(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      customerId: customerId ?? this.customerId,
      vendorId: vendorId ?? this.vendorId,
      driverId: driverId ?? this.driverId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      pickupTime: pickupTime ?? this.pickupTime,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }

  // Helper getters
  bool get isAssigned => driverId != null && driverId!.isNotEmpty;
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isDelivered => status.toLowerCase() == 'delivered';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isConfirmed => status.toLowerCase() == 'confirmed';
  
  double get deliveryFeeAsDouble {
    return double.tryParse(deliveryFee) ?? 0.0;
  }
  
  double? get latitude {
    return double.tryParse(deliveryLatitude);
  }
  
  double? get longitude {
    return double.tryParse(deliveryLongitude);
  }
}
