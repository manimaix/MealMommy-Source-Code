import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

class RouteService {
  static const List<String> _osrmServers = [
    'https://router.project-osrm.org',
    'https://routing.openstreetmap.de',
    'https://osrm.map.bf-ds.de',
  ];

  /// Calculate distance between two points using Haversine formula
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth radius in kilometers
    
    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Get route between two points using OSRM
  static Future<List<LatLng>> getRoute(LatLng start, LatLng destination) async {
    try {
      return await _getOSRMRoute(start, destination);
    } catch (e) {
      print('Error getting OSRM route: $e');
      // Fallback to realistic route
      return _createRealisticRoute(start, destination);
    }
  }

  /// Get optimized route for multiple waypoints
  static Future<List<LatLng>> getMultiPointRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return [];

    try {
      return await _getOSRMMultiPointRoute(waypoints);
    } catch (e) {
      print('Error getting multi-point route: $e');
      return _createRealisticMultiPointRoute(waypoints);
    }
  }

  static Future<List<LatLng>> _getOSRMRoute(LatLng start, LatLng destination) async {
    for (String server in _osrmServers) {
      try {
        final String url =
            '$server/route/v1/driving/'
            '${start.longitude},${start.latitude};'
            '${destination.longitude},${destination.latitude}'
            '?overview=full&geometries=geojson&steps=true';

        final response = await http
            .get(
              Uri.parse(url),
              headers: {'User-Agent': 'MealMommy/1.0 (Flutter App)'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            final coordinates = data['routes'][0]['geometry']['coordinates'] as List;

            return coordinates
                .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
                .toList();
          }
        }
      } catch (e) {
        print('Failed to get route from $server: $e');
        continue;
      }
    }

    throw Exception('All OSRM servers failed');
  }

  static Future<List<LatLng>> _getOSRMMultiPointRoute(List<LatLng> waypoints) async {
    for (String server in _osrmServers) {
      try {
        String coordinates = waypoints
            .map((point) => '${point.longitude},${point.latitude}')
            .join(';');

        final String url =
            '$server/route/v1/driving/$coordinates'
            '?overview=full&geometries=geojson&steps=true';

        final response = await http
            .get(
              Uri.parse(url),
              headers: {'User-Agent': 'MealMommy/1.0 (Flutter App)'},
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            final coordinates = data['routes'][0]['geometry']['coordinates'] as List;

            return coordinates
                .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
                .toList();
          }
        }
      } catch (e) {
        print('Failed to get multi-point route from $server: $e');
        continue;
      }
    }

    throw Exception('All OSRM servers failed for multi-point route');
  }

  static List<LatLng> _createRealisticRoute(LatLng start, LatLng destination) {
    final List<LatLng> waypoints = [start];
    
    final double latDiff = destination.latitude - start.latitude;
    final double lngDiff = destination.longitude - start.longitude;
    const int numWaypoints = 8;

    for (int i = 1; i < numWaypoints; i++) {
      final double progress = i / numWaypoints;
      double latOffset = latDiff * progress;
      double lngOffset = lngDiff * progress;

      // Add realistic variations
      if (i == 2) latOffset += latDiff * 0.1;
      if (i == 4) lngOffset += lngDiff * 0.15;
      if (i == 6) latOffset -= latDiff * 0.05;

      final double randomLat = (math.Random().nextDouble() - 0.5) * 0.002;
      final double randomLng = (math.Random().nextDouble() - 0.5) * 0.002;

      waypoints.add(LatLng(
        start.latitude + latOffset + randomLat,
        start.longitude + lngOffset + randomLng,
      ));
    }

    waypoints.add(destination);
    return waypoints;
  }

  static List<LatLng> _createRealisticMultiPointRoute(List<LatLng> waypoints) {
    List<LatLng> routePointsList = [];

    for (int i = 0; i < waypoints.length - 1; i++) {
      final LatLng start = waypoints[i];
      final LatLng end = waypoints[i + 1];

      if (i == 0) routePointsList.add(start);

      final double latDiff = end.latitude - start.latitude;
      final double lngDiff = end.longitude - start.longitude;
      final double distance = calculateDistance(start, end);
      final int numPoints = math.max(3, (distance * 5).round());

      for (int j = 1; j <= numPoints; j++) {
        final double progress = j / numPoints;
        double latOffset = latDiff * progress;
        double lngOffset = lngDiff * progress;

        final double curveFactor = math.sin(progress * math.pi) * 0.001;
        latOffset += curveFactor;
        lngOffset += curveFactor * 0.5;

        routePointsList.add(
          LatLng(start.latitude + latOffset, start.longitude + lngOffset),
        );
      }
    }

    return routePointsList;
  }
}
