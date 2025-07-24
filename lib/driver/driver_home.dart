import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../global_app_bar.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> with TickerProviderStateMixin {
  AppUser? currentUser;
  List<Map<String, dynamic>> groupOrders = [];
  bool isLoading = false;
  bool isOnline = false; // Online status for driver
  List<LatLng> routePoints = [];
  LatLng? selectedOrderLocation;
  String? selectedOrderId;
  List<LatLng> allDeliveryLocations = []; // For showing all delivery markers
  List<Map<String, dynamic>> currentGroupDeliveries = []; // Store current group deliveries data
  final LatLng driverLocation = LatLng(
    3.139,
    101.6869,
  ); // Current driver location (Kuala Lumpur)
  
  // Animation controllers for smooth expansion
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );
    _loadCurrentUser();
    _loadGroupOrders();
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      // Get the actual current user data from AuthService
      final userData = await AuthService.instance.getCurrentUserData();
      if (userData != null) {
        setState(() {
          currentUser = userData;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Fallback to basic Firebase user if available
      final basicUser = AuthService.instance.currentUser;
      if (basicUser != null) {
        setState(() {
          currentUser = basicUser;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _loadGroupOrders() async {
    setState(() {
      isLoading = true;
    });

    try {
      final orders = await getAllOrders();
      setState(() {
        groupOrders = orders;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading group orders: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('grouporders').get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) /
        1000; // Convert to kilometers
  }

  Future<void> getRoute(LatLng destination) async {
    try {
      // Primary method: Use OSRM (Open Source Routing Machine)
      await _getOSRMRoute(destination);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route loaded using OSRM real road data'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error getting route: $e');
      // Fallback: Create a realistic route approximation
      _createRealisticRoute(destination);

      // Show fallback message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using fallback route (OSRM unavailable)'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _getOSRMRoute(LatLng destination) async {
    // List of OSRM servers to try
    final List<String> osrmServers = [
      'https://router.project-osrm.org',
      'https://routing.openstreetmap.de',
      'https://osrm.map.bf-ds.de',
    ];

    for (String server in osrmServers) {
      try {
        final String url =
            '$server/route/v1/driving/'
            '${driverLocation.longitude},${driverLocation.latitude};'
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
            final coordinates =
                data['routes'][0]['geometry']['coordinates'] as List;

            setState(() {
              routePoints =
                  coordinates
                      .map<LatLng>(
                        (coord) => LatLng(
                          coord[1],
                          coord[0],
                        ), // OSRM returns [lon, lat]
                      )
                      .toList();
            });

            print('Successfully got route from OSRM server: $server');
            return;
          }
        }
      } catch (e) {
        print('Failed to get route from $server: $e');
        continue; // Try next server
      }
    }

    throw Exception('All OSRM servers failed');
  }

  void _createRealisticRoute(LatLng destination) {
    // Create a more realistic route by adding waypoints that simulate following roads
    final List<LatLng> waypoints = [];

    // Start point
    waypoints.add(driverLocation);

    // Calculate the difference
    final double latDiff = destination.latitude - driverLocation.latitude;
    final double lngDiff = destination.longitude - driverLocation.longitude;

    // Create waypoints that simulate following major roads
    // In Kuala Lumpur, roads often follow a grid-like pattern with some curves

    final int numWaypoints = 8; // More waypoints for smoother route

    for (int i = 1; i < numWaypoints; i++) {
      final double progress = i / numWaypoints;

      // Add some realistic variations to simulate following roads
      double latOffset = latDiff * progress;
      double lngOffset = lngDiff * progress;

      // Add road-like curves and turns
      if (i == 2) {
        // First turn - might go slightly north/south first
        latOffset += latDiff * 0.1;
      } else if (i == 4) {
        // Major road junction - slight detour
        lngOffset += lngDiff * 0.15;
      } else if (i == 6) {
        // Another turn to approach destination
        latOffset -= latDiff * 0.05;
      }

      // Add small random variations to make it look more natural
      final double randomLat = (math.Random().nextDouble() - 0.5) * 0.002;
      final double randomLng = (math.Random().nextDouble() - 0.5) * 0.002;

      waypoints.add(
        LatLng(
          driverLocation.latitude + latOffset + randomLat,
          driverLocation.longitude + lngOffset + randomLng,
        ),
      );
    }

    // End point
    waypoints.add(destination);

    setState(() {
      routePoints = waypoints;
    });
  }

  Future<List<Map<String, dynamic>>> getOrdersByGroupId(String groupId) async {
    final querySnapshot =
        await FirebaseFirestore.instance
            .collection('orders')
            .where('group_id', isEqualTo: groupId)
            .get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  Future<List<LatLng>> optimizeDeliveryRoute(List<Map<String, dynamic>> orders) async {
    if (orders.isEmpty) return [];

    // First, get vendor location from the first order's vendor_id
    LatLng? vendorLocation;
    if (orders.isNotEmpty && orders[0]['vendor_id'] != null) {
      vendorLocation = await getVendorLocation(orders[0]['vendor_id']);
    }

    // Convert orders to LatLng points with distances from vendor (or driver if vendor not found)
    LatLng startPoint = vendorLocation ?? driverLocation;
    List<Map<String, dynamic>> orderPoints =
        orders.map((order) {
          final double lat =
              double.tryParse(order['delivery_latitude'].toString()) ?? 0.0;
          final double lng =
              double.tryParse(order['delivery_longitude'].toString()) ?? 0.0;
          final LatLng point = LatLng(lat, lng);
          final double distance = calculateDistance(startPoint, point);

          return {'order': order, 'point': point, 'distance': distance};
        }).toList();

    // Sort by distance (nearest first from vendor location)
    orderPoints.sort((a, b) => a['distance'].compareTo(b['distance']));

    // Create optimized route: driver -> vendor -> nearest customer -> ... -> farthest customer
    List<LatLng> optimizedRoute = [driverLocation];
    
    // Add vendor location if found
    if (vendorLocation != null) {
      optimizedRoute.add(vendorLocation);
    }

    // Add all customer delivery locations
    for (var orderPoint in orderPoints) {
      optimizedRoute.add(orderPoint['point'] as LatLng);
    }

    return optimizedRoute;
  }

  Future<LatLng?> getVendorLocation(String vendorId) async {
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

  Future<void> getOptimizedGroupRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return;

    try {
      // Try to get OSRM route for multiple waypoints
      await _getOSRMMultiPointRoute(waypoints);
    } catch (e) {
      print('Error getting optimized route: $e');
      // Fallback: Create realistic multi-point route
      _createRealisticMultiPointRoute(waypoints);
    }
  }

  Future<void> _getOSRMMultiPointRoute(List<LatLng> waypoints) async {
    final List<String> osrmServers = [
      'https://router.project-osrm.org',
      'https://routing.openstreetmap.de',
      'https://osrm.map.bf-ds.de',
    ];

    for (String server in osrmServers) {
      try {
        // Build coordinates string for multiple waypoints
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
            final coordinates =
                data['routes'][0]['geometry']['coordinates'] as List;

            setState(() {
              routePoints =
                  coordinates
                      .map<LatLng>(
                        (coord) => LatLng(
                          coord[1],
                          coord[0],
                        ), // OSRM returns [lon, lat]
                      )
                      .toList();
            });

            print(
              'Successfully got multi-point route from OSRM server: $server',
            );
            return;
          }
        }
      } catch (e) {
        print('Failed to get multi-point route from $server: $e');
        continue;
      }
    }

    throw Exception('All OSRM servers failed for multi-point route');
  }

  void _createRealisticMultiPointRoute(List<LatLng> waypoints) {
    List<LatLng> routePointsList = [];

    // Create route segments between each pair of waypoints
    for (int i = 0; i < waypoints.length - 1; i++) {
      final LatLng start = waypoints[i];
      final LatLng end = waypoints[i + 1];

      // Add start point if it's the first segment
      if (i == 0) {
        routePointsList.add(start);
      }

      // Create realistic curve between points
      final double latDiff = end.latitude - start.latitude;
      final double lngDiff = end.longitude - start.longitude;
      final double distance = calculateDistance(start, end);

      // Number of intermediate points based on distance
      final int numPoints = math.max(3, (distance * 5).round());

      for (int j = 1; j <= numPoints; j++) {
        final double progress = j / numPoints;

        // Add realistic road-like variations
        double latOffset = latDiff * progress;
        double lngOffset = lngDiff * progress;

        // Add some curve variation
        final double curveFactor = math.sin(progress * math.pi) * 0.001;
        latOffset += curveFactor;
        lngOffset += curveFactor * 0.5;

        routePointsList.add(
          LatLng(start.latitude + latOffset, start.longitude + lngOffset),
        );
      }
    }

    setState(() {
      routePoints = routePointsList;
    });
  }

  void onOrderTapped(Map<String, dynamic> order) async {
    // If clicking the same order that's already selected, clear the route
    if (selectedOrderId == order['id']) {
      clearRoute();
      return;
    }

    // If a different route is already loaded, clear it first
    if (routePoints.isNotEmpty || allDeliveryLocations.isNotEmpty) {
      clearRoute();
    }

    // Since this comes from grouporders collection, treat it as a group order
    // Use the order ID as the group_id to find associated deliveries
    String groupId = order['group_id'] ?? order['id']; // Use order ID if no group_id field
    
    try {
      setState(() {
        selectedOrderId = order['id'];
      });

      final List<Map<String, dynamic>> groupDeliveries = await getOrdersByGroupId(groupId);

      if (groupDeliveries.isNotEmpty) {
        // Optimize the delivery route (driver -> vendor -> nearest to farthest customers)
        final List<LatLng> optimizedWaypoints = await optimizeDeliveryRoute(groupDeliveries);

        // Set markers for all delivery points (skip driver location, include vendor if present)
        setState(() {
          selectedOrderLocation = optimizedWaypoints.last; // Last delivery point for main marker
          allDeliveryLocations = optimizedWaypoints.skip(1).toList(); // Skip driver location
          currentGroupDeliveries = groupDeliveries; // Store delivery data
        });

        // Generate optimized route
        await getOptimizedGroupRoute(optimizedWaypoints);
        
        // Animate the expansion
        _expansionController.forward();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No deliveries found for this group. Try adding test orders first.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error loading group deliveries: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading group deliveries: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void onAcceptOrder(Map<String, dynamic> order) {
    // Check if driver is online before allowing order acceptance
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be ONLINE to accept orders'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // TODO: Implement accept order functionality
    print('Accept order tapped for order: ${order['id']}');
    
    // Show success message when order is accepted
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order ${order['id']} accepted successfully!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void toggleOnlineStatus() {
    setState(() {
      isOnline = !isOnline;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isOnline ? 'You are now ONLINE and available for orders' : 'You are now OFFLINE',
        ),
        backgroundColor: isOnline ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void clearRoute() {
    // Animate the collapse
    _expansionController.reverse();
    
    setState(() {
      routePoints.clear();
      selectedOrderLocation = null;
      selectedOrderId = null;
      allDeliveryLocations.clear();
      currentGroupDeliveries.clear();
    });
  }

  Future<void> _generateTestGroupOrder() async {
    try {
      // Create a test group order with the specified structure
      final testGroupOrder = {
        'created_by': '',
        'driver_id': '',
        'scheduled_time': Timestamp.fromDate(DateTime(2025, 7, 1, 2, 30, 55)),
        'status': 'open',
        'vendor_id': '',
      };

      // Add to grouporders collection
      final docRef = await FirebaseFirestore.instance
          .collection('grouporders')
          .add(testGroupOrder);

      // Create some test orders for this group
      final testOrders = [
        {
          'group_id': docRef.id,
          'vendor_id': 'test_vendor_1',
          'delivery_latitude': '3.1410',
          'delivery_longitude': '101.6890',
          'delivery_address': '123 Test Street, KL',
          'delivery_fee': '5.00',
          'status': 'pending',
          'created_at': Timestamp.now(),
        },
        {
          'group_id': docRef.id,
          'vendor_id': 'test_vendor_1',
          'delivery_latitude': '3.1450',
          'delivery_longitude': '101.6850',
          'delivery_address': '456 Sample Avenue, KL',
          'delivery_fee': '6.50',
          'status': 'pending',
          'created_at': Timestamp.now(),
        },
        {
          'group_id': docRef.id,
          'vendor_id': 'test_vendor_1',
          'delivery_latitude': '3.1380',
          'delivery_longitude': '101.6920',
          'delivery_address': '789 Demo Road, KL',
          'delivery_fee': '4.50',
          'status': 'pending',
          'created_at': Timestamp.now(),
        },
      ];

      // Add test orders to orders collection
      for (var order in testOrders) {
        await FirebaseFirestore.instance.collection('orders').add(order);
      }

      // Create test vendor user if doesn't exist
      final vendorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('test_vendor_1')
          .get();

      if (!vendorDoc.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc('test_vendor_1')
            .set({
          'uid': 'test_vendor_1',
          'email': 'testvendor@example.com',
          'name': 'Test Vendor Restaurant',
          'phone_number': '+60123456789',
          'address': 'Test Vendor Location, Kuala Lumpur',
          'address_latitude': '3.1400',
          'address_longitude': '101.6870',
          'role': 'vendor',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Reload group orders to show the new test data
      await _loadGroupOrders();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test group order with vendor route created successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error creating test group order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating test data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<Polyline> _createColoredRouteSegments() {
    if (routePoints.isEmpty || allDeliveryLocations.isEmpty) return [];
    
    // Colors for different route segments
    final List<Color> segmentColors = [
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
    
    // Calculate approximate segment points for each delivery
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

  double _calculateTotalDistance() {
    if (allDeliveryLocations.isEmpty) return 0.0;
    
    double totalDistance = 0.0;
    List<LatLng> allPoints = [driverLocation, ...allDeliveryLocations];
    
    // Calculate distance between consecutive points in the route
    for (int i = 0; i < allPoints.length - 1; i++) {
      totalDistance += calculateDistance(allPoints[i], allPoints[i + 1]);
    }
    
    return totalDistance;
  }

  double _calculateTotalDeliveryFee() {
    if (currentGroupDeliveries.isEmpty) return 0.0;
    
    double totalFee = 0.0;
    for (var delivery in currentGroupDeliveries) {
      final fee = double.tryParse(delivery['delivery_fee']?.toString() ?? '0') ?? 0.0;
      totalFee += fee;
    }
    
    return totalFee;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        currentUser: currentUser,
        isOnline: isOnline,
        onToggleOnline: toggleOnlineStatus,
        onSignOut: _signOut,
        onProfile: () {
          // Navigate to profile page
          print('Profile tapped');
        },
      ),
      body: Column(
        children: [
          // Top box - 55% of available space
          Expanded(
            flex: 11,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      3.139,
                      101.6869,
                    ), // Kuala Lumpur coordinates
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mealmommy',
                    ),
                    // Route polylines with different colors for each segment
                    if (routePoints.isNotEmpty && allDeliveryLocations.isNotEmpty)
                      PolylineLayer(
                        polylines: _createColoredRouteSegments(),
                      ),
                    MarkerLayer(
                      markers: [
                        // Driver location marker
                        Marker(
                          point: driverLocation,
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                        // All delivery location markers (for group orders) with matching colors
                        ...allDeliveryLocations.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final LatLng location = entry.value;
                          
                          // Colors matching route segments
                          final List<Color> markerColors = [
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
                          
                          // Check if this is the vendor location (first in allDeliveryLocations)
                          bool isVendor = index == 0 && allDeliveryLocations.length > 1;
                          
                          return Marker(
                            point: location,
                            child: Container(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    isVendor ? Icons.store : Icons.location_on,
                                    color: isVendor ? Colors.blue : markerColors[index % markerColors.length],
                                    size: isVendor ? 40 : 35,
                                  ),
                                  if (!isVendor)
                                    Positioned(
                                      top: 8,
                                      child: Text(
                                        '${index}', // Show number for customers (accounting for vendor at index 0)
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (isVendor)
                                    Positioned(
                                      top: 12,
                                      child: Text(
                                        'V',
                                        style: const TextStyle(
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
                        }).toList(),
                        // Main destination marker (if selected and not a group order)
                        if (selectedOrderLocation != null &&
                            allDeliveryLocations.isEmpty)
                          Marker(
                            point: selectedOrderLocation!,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom box - 45% of available space
          Expanded(
            flex: 9,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(),
              ),
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : groupOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'No group orders found',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _generateTestGroupOrder,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Generate Test Order'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: groupOrders.length,
                        itemBuilder: (context, index) {
                          final order = groupOrders[index];
                          final bool isSelected =
                              selectedOrderId == order['id'];

                          return GestureDetector(
                            onTap: () => onOrderTapped(order),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Colors.blue[50]
                                        : Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.blue
                                          : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'ID: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('${order['id'] ?? 'N/A'}'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text(
                                        'Scheduled Time: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_formatTimestamp(order['scheduled_time'])}',
                                      ),
                                    ],
                                  ),
                                  if (order['delivery_address'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Text(
                                          'Address: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${order['delivery_address']}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (order['status'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Text(
                                          'Status: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text('${order['status']}'),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Accept Order Button
                                      ElevatedButton.icon(
                                        onPressed: isOnline ? () => onAcceptOrder(order) : null,
                                        icon: Icon(
                                          Icons.check, 
                                          size: 18,
                                          color: isOnline ? Colors.white : Colors.grey[400],
                                        ),
                                        label: Text(
                                          isOnline ? 'Accept Order' : 'Go Online to Accept',
                                          style: TextStyle(
                                            color: isOnline ? Colors.white : Colors.grey[400],
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isOnline ? Colors.green : Colors.grey[300],
                                          foregroundColor: isOnline ? Colors.white : Colors.grey[400],
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          elevation: isOnline ? 2 : 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Animated Route Summary Extension (only for selected order with route)
                                  if (isSelected && routePoints.isNotEmpty && currentGroupDeliveries.isNotEmpty)
                                    SizeTransition(
                                      sizeFactor: _expansionAnimation,
                                      child: FadeTransition(
                                        opacity: _expansionAnimation,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.blue[200]!),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Distance',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey[600],
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          Text(
                                                            '${_calculateTotalDistance().toStringAsFixed(2)} km',
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.blue,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Total Fee',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey[600],
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          Text(
                                                            'RM ${_calculateTotalDeliveryFee().toStringAsFixed(2)}',
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.green,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Deliveries',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey[600],
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          Text(
                                                            '${currentGroupDeliveries.length} + vendor',
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.purple,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(Icons.route, size: 14, color: Colors.grey[600]),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Driver → Vendor → Customers',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateTestGroupOrder,
        icon: const Icon(Icons.add_location),
        label: const Text('Generate Test Order'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return 'Invalid date';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
