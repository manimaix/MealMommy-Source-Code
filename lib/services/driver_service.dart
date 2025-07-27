import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import 'route_service.dart';

class DriverService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get all available orders for driver (delegating to OrderService for complex filtering)
  static Future<List<GroupOrder>> getAvailableOrders({String? driverId}) async {
    try {
      Query query = _firestore.collection('grouporders');
      
      // If driverId provided, get both available and assigned orders
      if (driverId != null) {
        // Get all orders (will filter in UI)
        query = query.orderBy('created_at', descending: true);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return GroupOrder.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error getting orders: $e');
      return [];
    }
  }
  
  // Calculate distance between two points - delegate to RouteService
  static double calculateDistance(LatLng point1, LatLng point2) {
    return RouteService.calculateDistance(point1, point2);
  }
  
  // Listen to order updates for driver
  static Stream<List<GroupOrder>> getOrderUpdates(String driverId) {
    return _firestore
        .collection('grouporders')
        .where('driver_id', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupOrder.fromFirestore(
                doc.data(), doc.id))
            .toList());
  }
}
