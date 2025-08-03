import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../global_app_bar.dart';
import '../models/models.dart';
import '../services/route_service.dart';
import '../services/order_service.dart';
import '../services/delivery_route_service.dart';
import '../services/chat_service.dart';
import '../services/timer_utils_service.dart';
import '../services/location_service.dart';
import '../chat_page.dart';
import '../chat_room_list_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:async';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> with TickerProviderStateMixin {
  AppUser? currentUser;
  DeliveryPreferences? deliveryPreferences;
  List<GroupOrder> groupOrders = [];
  List<GroupOrder> filteredGroupOrders = []; // Filtered list for display
  bool isLoading = false;
  bool isOnline = false; // Online status for driver
  List<LatLng> routePoints = [];
  LatLng? selectedOrderLocation;
  String? selectedOrderId;
  List<LatLng> allDeliveryLocations = []; // For showing all delivery markers
  List<Order> currentGroupDeliveries = []; // Store current group deliveries data
  LatLng? driverLocation; // Will be set only when location permission is granted
  StreamSubscription<LatLng>? _locationSubscription;
  
  // Map controller for centering on driver location
  late MapController _mapController;
  
  // Filter settings
  String selectedFilter = 'all'; // 'all', 'my_orders', 'available', 'urgent', 'today'
  
  // Animation controllers for smooth expansion
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  
  // Stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    filteredGroupOrders = []; // Initialize filtered list
    _mapController = MapController(); // Initialize map controller
    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );
    _initializeLocationAndUser();
  }

  @override
  void dispose() {
    _expansionController.dispose();
    _ordersSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Initialize location services and user data
  Future<void> _initializeLocationAndUser() async {
    // Start with loading user first
    await _loadCurrentUser();
    
    // Then initialize location services
    await _initializeLocationServices();
  }

  /// Initialize location services and start tracking
  Future<void> _initializeLocationServices() async {
    try {
      // Since location permission is now handled in login page, we can directly try to get location
      final initialLocation = await LocationService.getCurrentPosition();
      if (initialLocation != null) {
        setState(() {
          driverLocation = initialLocation;
        });
        // Center map on initial driver location
        _mapController.move(initialLocation, 13.0);
      }
      
      // Start location tracking
      final trackingStarted = await LocationService.instance.startLocationTracking();
      if (trackingStarted) {
        _locationSubscription = LocationService.instance.locationStream.listen(
          (LatLng newLocation) {
            final oldLocation = driverLocation;
            setState(() {
              driverLocation = newLocation;
            });
            
            // Center map on new driver location
            _mapController.move(newLocation, _mapController.camera.zoom);
            
            // Calculate distance moved only if we had a previous location
            if (oldLocation != null) {
              final distanceMoved = LocationService.getDistanceBetween(oldLocation, newLocation);
              
              print('Driver location updated: ${newLocation.latitude}, ${newLocation.longitude}');
              print('Distance moved: ${distanceMoved.toStringAsFixed(0)}m');
              
              // Refresh orders if driver moved more than 100 meters
              // This ensures nearby orders are updated based on new location
              if (distanceMoved > 100) {
                print('Significant location change detected, refreshing orders...');
                _loadGroupOrders();
              }
            } else {
              print('Driver location set for first time: ${newLocation.latitude}, ${newLocation.longitude}');
              // Load orders for the first time when location is available
              _loadGroupOrders();
            }
          },
          onError: (error) {
            print('Location stream error: $error');
          },
        );
      } else {
        // Location tracking failed, but we already handled permission in login
        print('Location tracking failed to start');
        _showLocationErrorDialog('Failed to start location tracking');
      }
    } catch (e) {
      print('Error initializing location services: $e');
      _showLocationErrorDialog('Failed to initialize location services: $e');
    }
  }

  /// Show location error dialog
  void _showLocationErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            LocationService.openLocationSettings();
          },
        ),
      ),
    );
  }

  Future<void> _loadCurrentUser() async {
    try {
      // Get the actual current user data from AuthService
      final userData = await AuthService.instance.getCurrentUserData();
      if (userData != null) {
        setState(() {
          currentUser = userData;
        });
        // Load delivery preferences after user is loaded
        await _loadDeliveryPreferences();
        // Load group orders only if location is available
        if (driverLocation != null) {
          await _loadGroupOrders();
        }
        // Set up real-time listener
        _setupRealTimeListener();
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Fallback to basic Firebase user if available
      final basicUser = AuthService.instance.currentUser;
      if (basicUser != null) {
        setState(() {
          currentUser = basicUser;
        });
        await _loadDeliveryPreferences();
        // Load group orders only if location is available
        if (driverLocation != null) {
          await _loadGroupOrders();
        }
        // Set up real-time listener
        _setupRealTimeListener();
      }
    }
  }

  Future<void> _loadDeliveryPreferences() async {
    if (currentUser == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('deliverypreference')
          .doc(currentUser!.uid)
          .get();
      
      if (doc.exists && doc.data() != null) {
        setState(() {
          deliveryPreferences = DeliveryPreferences.fromFirestore(doc.data()!, doc.id);
        });
      } else {
        // Create default preferences if none exist
        final defaultPrefs = DeliveryPreferences.createDefault(
          driverId: currentUser!.uid,
        );
        
        await FirebaseFirestore.instance
            .collection('deliverypreference')
            .doc(currentUser!.uid)
            .set(defaultPrefs.toMap());
        
        setState(() {
          deliveryPreferences = defaultPrefs;
        });
      }
    } catch (e) {
      print('Error loading delivery preferences: $e');
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _loadGroupOrders() async {
    // Wait for current user and delivery preferences to be loaded
    if (currentUser == null || deliveryPreferences == null) {
      return;
    }
    
    // Only load orders if we have a valid location
    if (driverLocation == null) {
      print('No driver location available, skipping order loading');
      return;
    }
    
    setState(() {
      isLoading = true;
    });

    try {
      print('Loading orders with driver location: ${driverLocation!.latitude}, ${driverLocation!.longitude}');
      final orders = await getAllOrders();
      print('Total orders received: ${orders.length}');
      
      setState(() {
        groupOrders = orders;
        isLoading = false;
      });
      // Apply current filter after loading
      _applyFilter();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading group orders: $e');
    }
  }

  void _setupRealTimeListener() {
    if (currentUser == null) return;
    
    // Cancel existing subscription if any
    _ordersSubscription?.cancel();
    
    // Listen to grouporders collection for orders assigned to current driver
    _ordersSubscription = FirebaseFirestore.instance
        .collection('grouporders')
        .where('driver_id', isEqualTo: currentUser!.uid)
        .snapshots()
        .listen(
          (snapshot) {
            // Refresh orders when there are changes to driver's assigned orders
            _loadGroupOrders();
          },
          onError: (error) {
            print('Error in real-time listener: $error');
          },
        );
    
    // Also listen to orders collection for status changes
    FirebaseFirestore.instance
        .collection('orders')
        .where('driver_id', isEqualTo: currentUser!.uid)
        .snapshots()
        .listen(
          (snapshot) {
            // Check if any order status changed to 'delivered' or 'completed'
            bool hasDeliveredOrders = false;
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.modified) {
                final data = change.doc.data();
                if (data != null && 
                    (data['status'] == 'delivered' || data['status'] == 'completed')) {
                  hasDeliveredOrders = true;
                  break;
                }
              }
            }
            
            if (hasDeliveredOrders) {
              _loadGroupOrders();
            }
          },
          onError: (error) {
            print('Error in orders real-time listener: $error');
          },
        );
  }

  void _applyFilter() {
    if (currentUser == null) {
      setState(() {
        filteredGroupOrders = groupOrders;
      });
      return;
    }

    List<GroupOrder> filtered = [];
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime todayEnd = todayStart.add(Duration(days: 1));

    switch (selectedFilter) {
      case 'all':
        filtered = List.from(groupOrders);
        break;
        
      case 'my_orders':
        filtered = groupOrders.where((order) => 
          order.driverId == currentUser!.uid
        ).toList();
        break;
        
      case 'available':
        filtered = groupOrders.where((order) => 
          order.driverId == null || order.driverId!.isEmpty
        ).toList();
        break;
        
      case 'urgent':
        filtered = groupOrders.where((order) {
          if (order.scheduledTime == null) return false;
          final orderTime = order.scheduledTime!.toDate();
          final timeDiff = orderTime.difference(now);
          // Show orders due within next 2 hours or overdue
          return timeDiff.inHours <= 2;
        }).toList();
        break;
        
      case 'today':
        filtered = groupOrders.where((order) {
          if (order.scheduledTime == null) return false;
          final orderTime = order.scheduledTime!.toDate();
          return orderTime.isAfter(todayStart) && orderTime.isBefore(todayEnd);
        }).toList();
        break;
        
      default:
        filtered = List.from(groupOrders);
    }

    setState(() {
      filteredGroupOrders = filtered;
    });
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != selectedFilter) {
      setState(() {
        selectedFilter = newFilter;
      });
      _applyFilter();
    }
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.filter_list, color: Colors.grey[600], size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedFilter,
                  isExpanded: true,
                  style: TextStyle(color: Colors.grey[800], fontSize: 12),
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 16),
                  onChanged: _onFilterChanged,
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All Orders', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'my_orders',
                      child: Text('My Orders', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'available',
                      child: Text('Available', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'urgent',
                      child: Text('Urgent', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'today',
                      child: Text('Today', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '(${filteredGroupOrders.length})',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Public method to manually refresh orders (can be called from other widgets)
  Future<void> refreshOrders() async {
    await _loadGroupOrders();
  }

  Future<List<GroupOrder>> getAllOrders() async {
    // Return empty list if no location is available
    if (driverLocation == null) {
      return [];
    }
    
    final ordersData = await OrderService.getAllOrders(
      currentUserId: currentUser?.uid,
      deliveryPreferences: deliveryPreferences,
      driverLocation: driverLocation!,
    );
    
    final orders = ordersData.map((data) => GroupOrder.fromFirestore(data, data['id'] ?? '')).toList();
    
    // Sort orders by priority:
    orders.sort((a, b) {
      final bool aIsMyOrder = a.driverId == currentUser?.uid;
      final bool bIsMyOrder = b.driverId == currentUser?.uid;
      
      // My orders come first
      if (aIsMyOrder && !bIsMyOrder) return -1;
      if (!aIsMyOrder && bIsMyOrder) return 1;
      
      // If both are my orders or both are available, sort by scheduled time
      final DateTime now = DateTime.now();
      
      // Handle null scheduled times (put them at the end)
      if (a.scheduledTime == null && b.scheduledTime == null) return 0;
      if (a.scheduledTime == null) return 1;
      if (b.scheduledTime == null) return -1;
      
      final DateTime aTime = a.scheduledTime!.toDate();
      final DateTime bTime = b.scheduledTime!.toDate();
      
      // For my orders, show the most urgent ones first (closest to current time)
      if (aIsMyOrder && bIsMyOrder) {
        final Duration aDiff = aTime.difference(now).abs();
        final Duration bDiff = bTime.difference(now).abs();
        return aDiff.compareTo(bDiff);
      }
      
      // For available orders, show the earliest scheduled ones first
      return aTime.compareTo(bTime);
    });
    
    return orders;
  }



  double calculateDistance(LatLng point1, LatLng point2) {
    return RouteService.calculateDistance(point1, point2);
  }

  Future<void> getRoute(LatLng destination) async {
    if (driverLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available. Please enable location permissions.'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final route = await RouteService.getRoute(driverLocation!, destination);
      setState(() {
        routePoints = route;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route loaded successfully'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error getting route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error loading route'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<Order>> getOrdersByGroupId(String groupId) async {
    final ordersData = await OrderService.getOrdersByGroupId(groupId);
    return ordersData.map((data) => Order.fromFirestore(data, data['id'] ?? '')).toList();
  }

  Future<List<LatLng>> optimizeDeliveryRoute(List<Map<String, dynamic>> orders) async {
    if (driverLocation == null) {
      return [];
    }
    
    return await DeliveryRouteService.optimizeDeliveryRoute(
      orders: orders,
      driverLocation: driverLocation!,
    );
  }

  Future<LatLng?> getVendorLocation(String vendorId) async {
    return await DeliveryRouteService.getVendorLocation(vendorId);
  }

  Future<void> getOptimizedGroupRoute(List<LatLng> waypoints) async {
    try {
      final route = await RouteService.getMultiPointRoute(waypoints);
      setState(() {
        routePoints = route;
      });
    } catch (e) {
      print('Error getting optimized route: $e');
    }
  }

  double _calculateTotalDistance() {
    if (allDeliveryLocations.isEmpty || driverLocation == null) return 0.0;
    
    double totalDistance = 0.0;
    List<LatLng> allPoints = [driverLocation!, ...allDeliveryLocations];
    
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
      totalFee += delivery.deliveryFeeAsDouble;
    }
    
    return totalFee;
  }

  bool _isOrderReadyForDelivery(GroupOrder order) {
    return TimerUtilsService.isOrderReadyForDelivery(order.scheduledTime);
  }

  String _getTimeUntilReady(GroupOrder order) {
    return TimerUtilsService.getTimeUntilReady(order.scheduledTime);
  }

  void onOrderTapped(GroupOrder order) async {
    // If clicking the same order that's already selected, clear the route
    if (selectedOrderId == order.id) {
      clearRoute();
      return;
    }

    // If a different route is already loaded, clear it first
    if (routePoints.isNotEmpty || allDeliveryLocations.isNotEmpty) {
      clearRoute();
    }

    // Since this comes from grouporders collection, treat it as a group order
    // Use the order ID as the group_id to find associated deliveries
    String groupId = order.id; // Use order ID as the group_id
    
    try {
      setState(() {
        selectedOrderId = order.id;
      });

      final List<Order> groupDeliveries = await getOrdersByGroupId(groupId);

      if (groupDeliveries.isNotEmpty) {
        // Convert to Map format for optimizeDeliveryRoute compatibility
        final List<Map<String, dynamic>> deliveriesData = groupDeliveries.map((order) => order.toMap()..['id'] = order.id).toList();
        
        // Optimize the delivery route (driver -> vendor -> nearest to farthest customers)
        final List<LatLng> optimizedWaypoints = await optimizeDeliveryRoute(deliveriesData);

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
        
        // Show route loaded message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Route loaded! Ready for delivery.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
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

  void onAcceptOrder(GroupOrder order) async {
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

    if (currentUser == null || order.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to accept order'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // pass group order id to accept order
      final orderData = order.toMap()..['id'] = order.id;
      print(orderData);
      final success = await OrderService.acceptOrder(
        order: orderData,
        currentUserId: currentUser!.uid,
      );

      if (success) {
        // Update widget state immediately
        setState(() {
          final orderIndex = groupOrders.indexWhere((o) => o.id == order.id);
          if (orderIndex != -1) {
            groupOrders[orderIndex] = order.copyWith(
              assignedAt: Timestamp.now(),
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${order.id} accepted successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order has already been accepted by another driver'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        await _loadGroupOrders();
      }
    } catch (e) {
      print('Error accepting order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting order: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _navigateToLiveDelivery(GroupOrder order) async {
    // Check if location is available
    if (driverLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available. Please enable location permissions.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    try {
      // Check if the order is within 30 minutes of scheduled time
      if (order.scheduledTime != null) {
        final now = DateTime.now();
        final scheduledTime = order.scheduledTime!.toDate();
        final timeDifference = scheduledTime.difference(now);
        
        // If more than 30 minutes before scheduled time, show warning
        if (timeDifference.inMinutes > 30) {
          final hoursUntil = timeDifference.inHours;
          final minutesUntil = timeDifference.inMinutes % 60;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot start delivery yet. Please wait until 30 minutes before scheduled pickup time.\n'
                'Time remaining: ${hoursUntil > 0 ? '${hoursUntil}h ' : ''}${minutesUntil}m',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }

      // Get all deliveries for this group order
      String groupId = order.id;
      final List<Order> groupDeliveries = await getOrdersByGroupId(groupId);
      
      // Convert to Map format for optimizeDeliveryRoute compatibility
      final List<Map<String, dynamic>> deliveriesData = groupDeliveries.map((order) => order.toMap()..['id'] = order.id).toList();
      
      // Get the optimized route with vendor location
      final List<LatLng> optimizedWaypoints = await optimizeDeliveryRoute(deliveriesData);
      
      // Get vendor information
      LatLng? vendorLocation;
      Map<String, dynamic>? vendorInfo;
      if (groupDeliveries.isNotEmpty && groupDeliveries[0].vendorId.isNotEmpty) {
        vendorLocation = await getVendorLocation(groupDeliveries[0].vendorId);
        vendorInfo = await DeliveryRouteService.getVendorInfo(groupDeliveries[0].vendorId);
      }
      
      // Navigate to live delivery page with complete data (order items will be fetched there)
      final result = await Navigator.pushNamed(
        context,
        '/driver/live-delivery',
        arguments: {
          'groupOrder': order.toMap()..['id'] = order.id,
          'deliveries': deliveriesData,
          'optimizedWaypoints': optimizedWaypoints,
          'vendorLocation': vendorLocation,
          'vendorInfo': vendorInfo,
          'currentUser': currentUser,
          'driverLocation': driverLocation!,
        },
      );
      
      // Refresh orders when returning from live delivery page
      if (result != null || mounted) {
        await _loadGroupOrders();
        print('Refreshed orders after returning from live delivery');
      }
    } catch (e) {
      print('Error preparing live delivery data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading delivery data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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

  Color _getStatusColor(String? status) {
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

  Widget _buildCountdownTimer(dynamic scheduledTime) {
    if (scheduledTime == null) return const SizedBox.shrink();
    
    try {
      DateTime targetTime;
      if (scheduledTime is Timestamp) {
        targetTime = scheduledTime.toDate();
      } else if (scheduledTime is DateTime) {
        targetTime = scheduledTime;
      } else {
        return const SizedBox.shrink();
      }

      return StreamBuilder<DateTime>(
        stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
        builder: (context, snapshot) {
          final now = DateTime.now();
          final difference = targetTime.difference(now);
          
          if (difference.isNegative) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'OVERDUE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          
          final hours = difference.inHours;
          final minutes = difference.inMinutes % 60;
          final seconds = difference.inSeconds % 60;
          
          Color timerColor = Colors.green;
          if (hours == 0 && minutes < 30) {
            timerColor = Colors.red;
          } else if (hours == 0 && minutes < 60) {
            timerColor = Colors.orange;
          }
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: timerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              hours > 0 
                  ? '${hours}h ${minutes}m'
                  : '${minutes}m ${seconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }




  // Build small chat button for bottom right corner
  Widget _buildChatButton() {
    // Always show the button if user is logged in
    if (currentUser == null) {
      return SizedBox.shrink();
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.green[600], // Always green since we'll show all active chats
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () async {
            await _navigateToActiveDeliveryChat();
          },
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.chat_bubble,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              // Unread indicator dot
              StreamBuilder<bool>(
                stream: _getUnreadMessagesStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == true) {
                    return Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigate to chat room selection or directly to chat if only one room
  Future<void> _navigateToActiveDeliveryChat() async {
    if (currentUser == null) return;
    
    try {
      // Get all active chat rooms for the user
      final chatRooms = await ChatService.getUserChatRooms(currentUser!.uid);
      
      if (chatRooms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No active chat rooms found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (chatRooms.length == 1) {
        // Navigate directly to the single chat room
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                chatRoomId: chatRooms.first['id'],
                currentUserId: currentUser!.uid,
              ),
            ),
          );
        }
      } else {
        // Navigate to chat room selection page
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomListPage(
                currentUserId: currentUser!.uid,
                chatRooms: chatRooms,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error navigating to chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open chat'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Check for unread messages
  Stream<bool> _getUnreadMessagesStream() {
    if (currentUser == null) {
      return Stream.value(false);
    }
    
    return ChatService.hasUnreadMessages(currentUser!.uid).asStream();
  }

  // Generate test orders for development
  Future<void> _generateTestOrders() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now(); // Current time for created_at
      final scheduledTime = DateTime(2025, 7, 1, 10, 30, 55); // 1 July 2025 at 10:30:55
      final pickupTime = DateTime(2025, 7, 26, 1, 37, 24); // 26 July 2025 at 01:37:24
      final deliveryTime = DateTime(2025, 7, 26, 18, 4, 27); // 26 July 2025 at 18:04:27
      final updatedAt = DateTime(2025, 7, 26, 18, 3, 13); // 26 July 2025 at 18:03:13
      
      // The meal 'oncBK7euW3Guom4rD8Rt' already exists in database
      // We only need to create orders and order_items that reference this existing meal_id
      
      // Generate a group order with empty driver_id
      final groupOrderRef = FirebaseFirestore.instance.collection('grouporders').doc();
      final groupOrderData = {
        'assigned_at': null,
        'completed_at': null,
        'created_at': Timestamp.fromDate(now), // Today's date and time
        'current_delivery_index': 0,
        'current_navigation_step': 0,
        'driver_id': '', // Empty string for available orders
        'scheduled_time': Timestamp.fromDate(scheduledTime),
        'status': 'pending',
        'updated_at': Timestamp.fromDate(updatedAt),
        'vendor_id': 'test_vendor_1',
      };
      batch.set(groupOrderRef, groupOrderData);

      // Generate 5 individual orders linked to the group with meal items
      final List<Map<String, dynamic>> testOrders = [
        {
          'created_at': Timestamp.fromDate(now),
          'delivery_address': '789 Demo Road, KL',
          'delivery_fee': '4.50',
          'delivery_latitude': '3.1380',
          'delivery_longitude': '101.6920',
          'delivery_time': Timestamp.fromDate(deliveryTime),
          'group_id': groupOrderRef.id,
          'pickup_time': Timestamp.fromDate(pickupTime),
          'status': 'pending',
          'updated_at': Timestamp.fromDate(updatedAt),
          'vendor_id': 'test_vendor_1',
          'customer_name': 'John Doe',
          'customer_phone': '+60123456789',
          'total_amount': 60.00,
        },
        {
          'created_at': Timestamp.fromDate(now),
          'delivery_address': 'KLCC, Kuala Lumpur',
          'delivery_fee': '5.20',
          'delivery_latitude': '3.1578',
          'delivery_longitude': '101.7123',
          'delivery_time': Timestamp.fromDate(deliveryTime),
          'group_id': groupOrderRef.id,
          'pickup_time': Timestamp.fromDate(pickupTime),
          'status': 'pending',
          'updated_at': Timestamp.fromDate(updatedAt),
          'vendor_id': 'test_vendor_1',
          'customer_name': 'Jane Smith',
          'customer_phone': '+60123456790',
          'total_amount': 37.50,
        },
        {
          'created_at': Timestamp.fromDate(now),
          'delivery_address': 'Pavilion KL, Bukit Bintang',
          'delivery_fee': '6.80',
          'delivery_latitude': '3.1490',
          'delivery_longitude': '101.7140',
          'delivery_time': Timestamp.fromDate(deliveryTime),
          'group_id': groupOrderRef.id,
          'pickup_time': Timestamp.fromDate(pickupTime),
          'status': 'pending',
          'updated_at': Timestamp.fromDate(updatedAt),
          'vendor_id': 'test_vendor_1',
          'customer_name': 'Ahmad Rahman',
          'customer_phone': '+60123456791',
          'total_amount': 55.20,
        },
        {
          'created_at': Timestamp.fromDate(now),
          'delivery_address': 'Suria KLCC, Kuala Lumpur',
          'delivery_fee': '7.30',
          'delivery_latitude': '3.1588',
          'delivery_longitude': '101.7115',
          'delivery_time': Timestamp.fromDate(deliveryTime),
          'group_id': groupOrderRef.id,
          'pickup_time': Timestamp.fromDate(pickupTime),
          'status': 'pending',
          'updated_at': Timestamp.fromDate(updatedAt),
          'vendor_id': 'test_vendor_1',
          'customer_name': 'Sarah Lee',
          'customer_phone': '+60123456792',
          'total_amount': 41.40,
        },
        {
          'created_at': Timestamp.fromDate(now),
          'delivery_address': 'Mid Valley Megamall, KL',
          'delivery_fee': '8.70',
          'delivery_latitude': '3.1184',
          'delivery_longitude': '101.6770',
          'delivery_time': Timestamp.fromDate(deliveryTime),
          'group_id': groupOrderRef.id,
          'pickup_time': Timestamp.fromDate(pickupTime),
          'status': 'pending',
          'updated_at': Timestamp.fromDate(updatedAt),
          'vendor_id': 'test_vendor_1',
          'customer_name': 'David Tan',
          'customer_phone': '+60123456793',
          'total_amount': 33.00,
        },
      ];

      // Generate order items for each order (following exact database schema)
      final List<List<Map<String, dynamic>>> orderItemsData = [
        // John Doe's order items
        [
          {
            'meal_id': 'oncBK7euW3Guom4rD8Rt',
            'quantity': 4,
            'subtotal': 60,
          },
        ],
        // Jane Smith's order items  
        [
          {
            'meal_id': 'oncBK7euW3Guom4rD8Rt',
            'quantity': 3,
            'subtotal': 37,
          },
        ],
        // Ahmad Rahman's order items
        [
          {
            'meal_id': 'oncBK7euW3Guom4rD8Rt',
            'quantity': 2,
            'subtotal': 30,
          },
          {
            'meal_id': 'oncBK7euW3Guom4rD8Rt',
            'quantity': 1,
            'subtotal': 14,
          },
          {
            'meal_id': 'oncBK7euW3Guom4rD8Rt',
            'quantity': 1,
            'subtotal': 9,
          },
        ],
        // Sarah Lee's order items
        [
          {
            'meal_id': 'oncBK7euW3Guom4rD8Rt',
            'quantity': 3,
            'subtotal': 41,
          },
        ],
        // David Tan's order items
        [
          {
            'meal_id': 'oncBK7euW3Guom4rD8Rt',
            'quantity': 3,
            'subtotal': 33,
          },
        ],
      ];

      // Add individual orders to batch with their items
      for (int i = 0; i < testOrders.length; i++) {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc();
        batch.set(orderRef, testOrders[i]);
        
        // Add order items for this order (following exact database schema)
        for (var itemData in orderItemsData[i]) {
          final orderItemRef = FirebaseFirestore.instance.collection('order_items').doc();
          final orderItemWithOrderId = {
            'meal_id': itemData['meal_id'], // String
            'order_id': orderRef.id, // String
            'quantity': itemData['quantity'], // Number
            'subtotal': itemData['subtotal'], // Number (no decimal places as per your schema)
          };
          batch.set(orderItemRef, orderItemWithOrderId);
        }
      }

      // Commit the batch
      await batch.commit();

      // Debug: Print what was created
      print('=== DEBUG: Test Data Generated ===');
      print('Using existing meal with ID: oncBK7euW3Guom4rD8Rt');
      print('Created 1 group order with ID: ${groupOrderRef.id}');
      print('Created ${testOrders.length} individual orders');
      
      int totalOrderItems = 0;
      for (int i = 0; i < orderItemsData.length; i++) {
        totalOrderItems += orderItemsData[i].length;
        print('Order ${i + 1}: ${orderItemsData[i].length} items');
      }
      print('Total order items created: $totalOrderItems');
      print('All order items reference existing meal_id: oncBK7euW3Guom4rD8Rt');
      print('===================================');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test group order with 5 linked orders generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Refresh orders to show new test data
        await _loadGroupOrders();
      }
    } catch (e) {
      print('Error generating test orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating test orders: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Build test order generation button
  Widget _buildOrderGenerationButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.orange[600],
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: _generateTestOrders,
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.add_shopping_cart,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      body: Stack(
        children: [
          Column(
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
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: driverLocation ?? LatLng(
                      3.139,
                      101.6869,
                    ), // Use driver location if available, otherwise default to Kuala Lumpur
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
                        // Driver location marker - only show if location is available
                        if (driverLocation != null)
                          Marker(
                            point: driverLocation!,
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
                      ? RefreshIndicator(
                          onRefresh: () async {
                            await _loadGroupOrders();
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 200),
                              Center(
                                child: Column(
                                  children: [
                                    if (driverLocation == null) ...[
                                      Icon(
                                        Icons.location_off,
                                        size: 48,
                                        color: Colors.red[400],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Location Required',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Please enable location permissions\nto view available orders',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.inbox_outlined,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No group orders found\nPull down to refresh',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Filter dropdown
                            _buildFilterDropdown(),
                            // Divider
                            Divider(height: 1, color: Colors.grey[300]),
                            // Orders list
                            Expanded(
                              child: filteredGroupOrders.isEmpty
                                  ? RefreshIndicator(
                                      onRefresh: () async {
                                        await _loadGroupOrders();
                                      },
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return SingleChildScrollView(
                                            physics: const AlwaysScrollableScrollPhysics(),
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minHeight: constraints.maxHeight,
                                              ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.filter_list_off, 
                                                         size: 48, 
                                                         color: Colors.grey[400]),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'No orders match your filter\nTry changing the filter or pull to refresh',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: () async {
                                        await _loadGroupOrders();
                                      },
                                      child: ListView.builder(
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.all(16),
                                        itemCount: filteredGroupOrders.length,
                                        itemBuilder: (context, index) {
                                          final order = filteredGroupOrders[index];
                          final bool isSelected =
                              selectedOrderId == order.id;
                          final bool isAssignedToMe = 
                              order.driverId == currentUser?.uid;

                          return GestureDetector(
                            onTap: () => onOrderTapped(order),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Colors.blue[50]
                                        : isAssignedToMe 
                                            ? Colors.green[50]
                                            : Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.blue
                                          : isAssignedToMe
                                              ? Colors.green
                                              : Colors.grey[300]!,
                                  width: isSelected || isAssignedToMe ? 2 : 1,
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
                                      Text('${order.id}'),
                                      if (isAssignedToMe) ...[
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8, 
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'MY ORDER',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
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
                                        '${TimerUtilsService.formatTimestamp(order.scheduledTime)}',
                                      ),
                                      if (isAssignedToMe && order.scheduledTime != null) ...[
                                        const SizedBox(width: 8),
                                        _buildCountdownTimer(order.scheduledTime),
                                      ],
                                    ],
                                  ),
                                  if (order.status.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Text(
                                          'Status: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(order.status),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${order.status}'.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Different button based on order status
                                      if (isAssignedToMe)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: _isOrderReadyForDelivery(order) 
                                                  ? () => _navigateToLiveDelivery(order)
                                                  : null,
                                              icon: Icon(
                                                _isOrderReadyForDelivery(order) ? Icons.navigation : Icons.schedule,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                              label: Text(
                                                _isOrderReadyForDelivery(order) ? 'View Order' : 'Not Ready',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _isOrderReadyForDelivery(order) 
                                                    ? Colors.blue 
                                                    : Colors.grey,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                elevation: 2,
                                              ),
                                            ),
                                            if (!_isOrderReadyForDelivery(order))
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4, left: 4),
                                                child: Text(
                                                  _getTimeUntilReady(order),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        )
                                      else
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
            ),
          ),
          ],
        ),
          // Positioned order generation button above chat button
          Positioned(
            bottom: 90, // Position above chat button
            right: 20,
            child: _buildOrderGenerationButton(),
          ),
          // Positioned chat button in bottom right
          Positioned(
            bottom: 20,
            right: 20,
            child: _buildChatButton(),
          ),
        ],
      ),
    );
  }

}