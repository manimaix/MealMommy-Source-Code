import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class MapUtilsService {
  /// Create colored route segments for visualization
  static List<Polyline> createColoredRouteSegments({
    required List<LatLng> routePoints,
    required List<LatLng> allDeliveryLocations,
  }) {
    if (routePoints.isEmpty || allDeliveryLocations.isEmpty) return [];
    
    const List<Color> segmentColors = [
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.teal,
      Colors.brown,
    ];
    
    List<Polyline> polylines = [];
    int pointsPerSegment = (routePoints.length / (allDeliveryLocations.length + 1)).round();
    
    for (int i = 0; i < allDeliveryLocations.length; i++) {
      int startIndex = i * pointsPerSegment;
      int endIndex = math.min((i + 1) * pointsPerSegment + 1, routePoints.length);
      
      if (startIndex < routePoints.length && endIndex > startIndex) {
        polylines.add(
          Polyline(
            points: routePoints.sublist(startIndex, endIndex),
            strokeWidth: 4.0,
            color: segmentColors[i % segmentColors.length],
          ),
        );
      }
    }
    
    return polylines;
  }

  /// Create markers for driver, vendor, and delivery locations
  static List<Marker> createDeliveryMarkers({
    required LatLng driverLocation,
    required List<LatLng> allDeliveryLocations,
    LatLng? selectedOrderLocation,
  }) {
    List<Marker> markers = [];

    // Driver location marker
    markers.add(
      Marker(
        point: driverLocation,
        child: const Icon(
          Icons.local_shipping,
          color: Colors.green,
          size: 40,
        ),
      ),
    );

    // Delivery location markers with colors and numbers
    const List<Color> markerColors = [
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.teal,
      Colors.brown,
    ];

    for (int i = 0; i < allDeliveryLocations.length; i++) {
      final LatLng location = allDeliveryLocations[i];
      final bool isVendor = i == 0 && allDeliveryLocations.length > 1;
      
      markers.add(
        Marker(
          point: location,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                isVendor ? Icons.store : Icons.location_on,
                color: isVendor ? Colors.blue : markerColors[i % markerColors.length],
                size: isVendor ? 40 : 35,
              ),
              if (!isVendor)
                Positioned(
                  top: 8,
                  child: Text(
                    '$i', // Show number for customers
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (isVendor)
                const Positioned(
                  top: 12,
                  child: Text(
                    'V',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Single order marker (if not a group order)
    if (selectedOrderLocation != null && allDeliveryLocations.isEmpty) {
      markers.add(
        Marker(
          point: selectedOrderLocation,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    }

    return markers;
  }

  /// Get status color based on order status
  static Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'closed':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
