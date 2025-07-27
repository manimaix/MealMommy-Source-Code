import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'route_service.dart';

class DeliveryRouteService {
  /// Optimize delivery route: driver -> vendor -> nearest to farthest customers
  static Future<List<LatLng>> optimizeDeliveryRoute({
    required List<Map<String, dynamic>> orders,
    required LatLng driverLocation,
  }) async {
    if (orders.isEmpty) return [];

    // Get vendor location from first order
    LatLng? vendorLocation;
    if (orders.isNotEmpty && orders[0]['vendor_id'] != null) {
      vendorLocation = await getVendorLocation(orders[0]['vendor_id']);
    }

    // Convert orders to points with distances from vendor (or driver if vendor not found)
    LatLng startPoint = vendorLocation ?? driverLocation;
    List<Map<String, dynamic>> orderPoints = orders.map((order) {
      final double lat = double.tryParse(order['delivery_latitude'].toString()) ?? 0.0;
      final double lng = double.tryParse(order['delivery_longitude'].toString()) ?? 0.0;
      final LatLng point = LatLng(lat, lng);
      final double distance = RouteService.calculateDistance(startPoint, point);

      return {'order': order, 'point': point, 'distance': distance};
    }).toList();

    // Sort by distance (nearest first from vendor location)
    orderPoints.sort((a, b) => a['distance'].compareTo(b['distance']));

    // Create optimized route
    List<LatLng> optimizedRoute = [driverLocation];
    
    if (vendorLocation != null) {
      optimizedRoute.add(vendorLocation);
    }

    for (var orderPoint in orderPoints) {
      optimizedRoute.add(orderPoint['point'] as LatLng);
    }

    return optimizedRoute;
  }

  /// Get vendor location from user collection
  static Future<LatLng?> getVendorLocation(String vendorId) async {
    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(vendorId)
          .get();

      if (vendorDoc.exists) {
        final data = vendorDoc.data() as Map<String, dynamic>;
        final double? lat = double.tryParse(data['address_latitude']?.toString() ?? '');
        final double? lng = double.tryParse(data['address_longitude']?.toString() ?? '');
        
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      print('Error getting vendor location: $e');
    }
    return null;
  }

  /// Get vendor information
  static Future<Map<String, dynamic>?> getVendorInfo(String vendorId) async {
    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(vendorId)
          .get();
      
      if (vendorDoc.exists) {
        final vendorInfo = vendorDoc.data() as Map<String, dynamic>;
        vendorInfo['id'] = vendorDoc.id;
        return vendorInfo;
      }
    } catch (e) {
      print('Error getting vendor info: $e');
    }
    return null;
  }

  /// Calculate total distance for a route
  static double calculateTotalDistance(List<LatLng> waypoints) {
    if (waypoints.isEmpty) return 0.0;
    
    double totalDistance = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDistance += RouteService.calculateDistance(waypoints[i], waypoints[i + 1]);
    }
    
    return totalDistance;
  }

  /// Calculate total delivery fee for multiple deliveries
  static double calculateTotalDeliveryFee(List<Map<String, dynamic>> deliveries) {
    double totalFee = 0.0;
    for (var delivery in deliveries) {
      final fee = double.tryParse(delivery['delivery_fee']?.toString() ?? '0') ?? 0.0;
      totalFee += fee;
    }
    return totalFee;
  }
}
