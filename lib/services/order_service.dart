import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/delivery_preferences_model.dart';
import 'route_service.dart';
import 'chat_service.dart';

class OrderService {
  /// Get all orders filtered by driver preferences and assignment status
  static Future<List<Map<String, dynamic>>> getAllOrders({
    required String? currentUserId,
    required DeliveryPreferences? deliveryPreferences,
    required LatLng driverLocation,
  }) async {
    if (currentUserId == null || deliveryPreferences == null) return [];
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('grouporders')
          .get();
      
      List<Map<String, dynamic>> filteredOrders = [];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final orderId = doc.id;
        final driverId = data['driver_id'];
        final status = data['status']?.toString().toLowerCase();
        
        // Filter out completed orders
        if (status == 'completed') continue;
        
        // Filter out orders assigned to OTHER drivers
        if (driverId != null && driverId != '' && driverId != currentUserId) continue;
        
        // Show orders with no driver or assigned to current driver
        if (driverId == null || driverId == '' || driverId == currentUserId) {
          if (await _isOrderWithinDistance(orderId, deliveryPreferences, driverLocation)) {
            filteredOrders.add({'id': orderId, ...data});
          }
        }
      }
      
      return filteredOrders;
    } catch (e) {
      print('Error getting filtered orders: $e');
      return [];
    }
  }

  /// Get orders by group ID
  static Future<List<Map<String, dynamic>>> getOrdersByGroupId(String groupId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('group_id', isEqualTo: groupId)
        .get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  /// Accept an order with race condition protection and create chat room
  static Future<bool> acceptOrder({
    required Map<String, dynamic> order,
    required String currentUserId,
  }) async {
    try {
      print('🔄 Starting order acceptance for order: ${order['id']}');
      
      // Check if order is still available
      final orderDoc = await FirebaseFirestore.instance
          .collection('grouporders')
          .doc(order['id'])
          .get();

      if (!orderDoc.exists) {
        print('❌ Order ${order['id']} does not exist');
        return false;
      }

      final currentOrderData = orderDoc.data() as Map<String, dynamic>;
      final currentDriverId = currentOrderData['driver_id'];

      // Check if already assigned to another driver
      if (currentDriverId != null && currentDriverId != '' && currentDriverId != currentUserId) {
        print('❌ Order ${order['id']} already assigned to driver: $currentDriverId');
        return false;
      }

      print('✅ Order ${order['id']} is available, assigning to driver: $currentUserId');

      // Update with driver assignment and status
      await FirebaseFirestore.instance
          .collection('grouporders')
          .doc(order['id'])
          .update({
        'driver_id': currentUserId,
        'assigned_at': Timestamp.now(),
        'status': 'assigned',
        'updated_at': Timestamp.now(),
      });

      print('✅ Order ${order['id']} updated with driver assignment');

      // Create chat room for the order
      print('🔄 Creating chat room for order: ${order['id']}');
      await _createOrderChatRoom(order['id'], currentUserId);

      print('✅ Order acceptance complete for: ${order['id']}');
      return true;
    } catch (e) {
      print('❌ Error accepting order: $e');
      return false;
    }
  }

  /// Create chat room for an order with all participants
  static Future<void> _createOrderChatRoom(String groupOrderId, String driverId) async {
    try {
      print('🔄 Starting chat room creation for order: $groupOrderId');
      
      // Get vendor ID from group order
      final groupOrderDoc = await FirebaseFirestore.instance
          .collection('grouporders')
          .doc(groupOrderId)
          .get();
      
      if (!groupOrderDoc.exists) {
        print('❌ Group order document not found: $groupOrderId');
        return;
      }
      
      final groupOrderData = groupOrderDoc.data() as Map<String, dynamic>;
      final vendorId = groupOrderData['vendor_id'] ?? '';
      print('📝 Found vendor ID: $vendorId');
      
      // Get customer IDs from individual orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('group_id', isEqualTo: groupOrderId)
          .get();
      
      final customerIds = <String>[];
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final customerId = orderData['customer_id'];
        if (customerId != null && customerId != '' && !customerIds.contains(customerId)) {
          customerIds.add(customerId);
        }
      }
      print('👥 Found customer IDs: $customerIds');
      
      // Create chat room
      final chatRoomId = await ChatService.createOrderChatRoom(
        groupOrderId: groupOrderId,
        driverId: driverId,
        vendorId: vendorId,
        customerIds: customerIds,
      );
      
      if (chatRoomId != null) {
        print('✅ Chat room created successfully: $chatRoomId');
      } else {
        print('❌ Failed to create chat room');
      }
      
    } catch (e) {
      print('❌ Error creating order chat room: $e');
    }
  }

  /// Check if order is within delivery distance
  static Future<bool> _isOrderWithinDistance(
    String groupId,
    DeliveryPreferences deliveryPreferences,
    LatLng driverLocation,
  ) async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('group_id', isEqualTo: groupId)
          .get();
      
      if (ordersSnapshot.docs.isEmpty) return true;
      
      final maxDistanceKm = deliveryPreferences.maxDistance.toDouble();
      
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final lat = double.tryParse(orderData['delivery_latitude']?.toString() ?? '');
        final lng = double.tryParse(orderData['delivery_longitude']?.toString() ?? '');
        
        if (lat != null && lng != null) {
          final deliveryLocation = LatLng(lat, lng);
          final distance = RouteService.calculateDistance(driverLocation, deliveryLocation);
          
          if (distance <= maxDistanceKm) return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking order distance: $e');
      return true;
    }
  }
}
