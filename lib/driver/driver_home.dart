import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../global_app_bar.dart';
import '../models/models.dart';
import '../services/route_service.dart';
import '../services/order_service.dart';
import '../services/delivery_route_service.dart';
import '../services/chat_service.dart';
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
  bool isLoading = false;
  bool isOnline = false; // Online status for driver
  List<LatLng> routePoints = [];
  LatLng? selectedOrderLocation;
  String? selectedOrderId;
  List<LatLng> allDeliveryLocations = []; // For showing all delivery markers
  List<Order> currentGroupDeliveries = []; // Store current group deliveries data
  final LatLng driverLocation = LatLng(
    3.139,
    101.6869,
  ); // Current driver location (Kuala Lumpur)
  
  // Animation controllers for smooth expansion
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  
  // Stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _ordersSubscription;

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
  }

  @override
  void dispose() {
    _expansionController.dispose();
    _ordersSubscription?.cancel();
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
        // Load delivery preferences after user is loaded
        await _loadDeliveryPreferences();
        // Load group orders after preferences are loaded
        await _loadGroupOrders();
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
        await _loadGroupOrders();
        // Set up real-time listener
        _setupRealTimeListener();
      }
    }
  }

  Future<void> _loadDeliveryPreferences() async {
    if (currentUser == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('delivery_preferences')
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
            .collection('delivery_preferences')
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
            print('Real-time update: Driver orders changed, refreshing list');
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
              print('Real-time update: Order delivery status changed, refreshing list');
            }
          },
          onError: (error) {
            print('Error in orders real-time listener: $error');
          },
        );
  }

  // Public method to manually refresh orders (can be called from other widgets)
  Future<void> refreshOrders() async {
    await _loadGroupOrders();
  }

  Future<List<GroupOrder>> getAllOrders() async {
    final ordersData = await OrderService.getAllOrders(
      currentUserId: currentUser?.uid,
      deliveryPreferences: deliveryPreferences,
      driverLocation: driverLocation,
    );
    
    return ordersData.map((data) => GroupOrder.fromFirestore(data, data['id'] ?? '')).toList();
  }



  double calculateDistance(LatLng point1, LatLng point2) {
    return RouteService.calculateDistance(point1, point2);
  }

  Future<void> getRoute(LatLng destination) async {
    try {
      final route = await RouteService.getRoute(driverLocation, destination);
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
    return await DeliveryRouteService.optimizeDeliveryRoute(
      orders: orders,
      driverLocation: driverLocation,
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
      final orderData = order.toMap()..['id'] = order.id;
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
    try {
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
      
      // Navigate to live delivery page with complete data
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
          'driverLocation': driverLocation,
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
      totalFee += delivery.deliveryFeeAsDouble;
    }
    
    return totalFee;
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

  // Build dev tools button for testing
  Widget _buildDevToolsButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.orange[600],
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            _showDevToolsMenu();
          },
          child: Center(
            child: Icon(
              Icons.developer_mode,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // Show dev tools menu
  void _showDevToolsMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🛠️ Dev Tools',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
                SizedBox(height: 20),
                _buildDevToolButton(
                  'Create Sample Group Order',
                  Icons.add_shopping_cart,
                  () => _createSampleGroupOrder(),
                ),
                SizedBox(height: 12),
                _buildDevToolButton(
                  'List All Chat Rooms',
                  Icons.chat_bubble_outline,
                  () => _listAllChatRooms(),
                ),
                SizedBox(height: 12),
                _buildDevToolButton(
                  'Clear All Test Data',
                  Icons.delete_sweep,
                  () => _clearTestData(),
                ),
                SizedBox(height: 12),
                _buildDevToolButton(
                  'Create Test Users',
                  Icons.people,
                  () => _createTestUsers(),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDevToolButton(String title, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[100],
          foregroundColor: Colors.orange[700],
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // Dev Tools Functions
  Future<void> _createSampleGroupOrder() async {
    Navigator.of(context).pop(); // Close dialog first
    
    try {
      // Create sample group order with auto-generated ID
      final groupOrderRef = FirebaseFirestore.instance.collection('grouporders').doc();
      final groupOrderId = groupOrderRef.id;
      
      // Create sample group order with your exact structure
      await groupOrderRef.set({
        'assigned_at': Timestamp.fromDate(DateTime.parse('2025-07-26 00:39:11')),
        'completed_at': Timestamp.fromDate(DateTime.parse('2025-07-26 01:32:01')),
        'current_delivery_index': 2,
        'current_navigation_step': 3,
        'driver_id': "",
        'scheduled_time': Timestamp.fromDate(DateTime.parse('2025-07-01 02:30:55')),
        'status': 'pending', // Set as pending so it can be accepted
        'updated_at': Timestamp.now(),
        'vendor_id': '',
      });

      // Create sample individual orders with your exact structure
      final sampleOrders = [
        {
          'created_at': Timestamp.fromDate(DateTime.parse('2025-07-25 07:01:54')),
          'delivery_address': '123 Test Street, KL',
          'delivery_fee': '5.00',
          'delivery_latitude': '3.1410',
          'delivery_longitude': '101.6890',
          'delivery_time': Timestamp.fromDate(DateTime.parse('2025-07-26 01:32:01')),
          'group_id': groupOrderId,
          'pickup_time': Timestamp.fromDate(DateTime.parse('2025-07-26 01:28:40')),
          'status': 'confirmed', // Set as confirmed so it's ready for delivery
          'updated_at': Timestamp.now(),
          'vendor_id': 'test_vendor_1',
          'customer_id': 'customer_sample_1', // Add customer ID for chat room creation
        },
        {
          'created_at': Timestamp.fromDate(DateTime.parse('2025-07-25 07:01:54')),
          'delivery_address': '456 Another Street, KL',
          'delivery_fee': '5.00',
          'delivery_latitude': '3.1500',
          'delivery_longitude': '101.7000',
          'delivery_time': Timestamp.fromDate(DateTime.parse('2025-07-26 01:35:01')),
          'group_id': groupOrderId,
          'pickup_time': Timestamp.fromDate(DateTime.parse('2025-07-26 01:28:40')),
          'status': 'confirmed',
          'updated_at': Timestamp.now(),
          'vendor_id': 'test_vendor_1',
          'customer_id': 'customer_sample_2', // Add customer ID for chat room creation
        }
      ];

      final batch = FirebaseFirestore.instance.batch();
      for (var order in sampleOrders) {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc();
        batch.set(orderRef, order);
      }
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sample group order created: $groupOrderId'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh orders
      await _loadGroupOrders();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error creating sample order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _listAllChatRooms() async {
    Navigator.of(context).pop(); // Close dialog first
    
    try {
      final chatRooms = await FirebaseFirestore.instance
          .collection('chatrooms')
          .get();

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '💬 All Chat Rooms (${chatRooms.docs.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: chatRooms.docs.length,
                    itemBuilder: (context, index) {
                      final chatRoom = chatRooms.docs[index];
                      final data = chatRoom.data();
                      return Card(
                        child: ListTile(
                          title: Text('ID: ${chatRoom.id}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Participants: ${data['participants']?.length ?? 0}'),
                              Text('Status: ${data['status'] ?? 'N/A'}'),
                              Text('Last: ${data['lastMessage'] ?? 'No messages'}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error listing chat rooms: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearTestData() async {
    Navigator.of(context).pop(); // Close dialog first
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Clear Test Data'),
        content: Text('This will delete all sample orders and chat rooms. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                // Delete sample group orders (by vendor_id = empty string or test_vendor_1)
                final sampleOrders = await FirebaseFirestore.instance
                    .collection('grouporders')
                    .where('vendor_id', whereIn: ['', 'test_vendor_1'])
                    .get();

                final batch = FirebaseFirestore.instance.batch();
                for (var doc in sampleOrders.docs) {
                  batch.delete(doc.reference);
                }

                // Delete sample individual orders
                final sampleIndividualOrders = await FirebaseFirestore.instance
                    .collection('orders')
                    .where('vendor_id', isEqualTo: 'test_vendor_1')
                    .get();

                for (var doc in sampleIndividualOrders.docs) {
                  batch.delete(doc.reference);
                }

                // Delete sample chat rooms (containing test data)
                final allChatRooms = await FirebaseFirestore.instance
                    .collection('chatrooms')
                    .get();

                for (var doc in allChatRooms.docs) {
                  final data = doc.data();
                  final participants = data['participants'] as List<dynamic>? ?? [];
                  
                  // Delete if contains sample users
                  if (participants.contains('customer_sample_1') || 
                      participants.contains('customer_sample_2') ||
                      participants.contains('vendor_sample') ||
                      doc.id.contains('sample_')) {
                    batch.delete(doc.reference);
                  }
                }

                // Delete sample chat messages
                final allMessages = await FirebaseFirestore.instance
                    .collection('chatmessages')
                    .get();

                for (var doc in allMessages.docs) {
                  final data = doc.data();
                  final chatRoomId = data['chatRoomId'] as String? ?? '';
                  
                  // Delete messages from sample chat rooms
                  if (chatRoomId.contains('sample_') || chatRoomId.startsWith('chat_sample_')) {
                    batch.delete(doc.reference);
                  }
                }

                await batch.commit();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Test data cleared successfully'),
                    backgroundColor: Colors.green,
                  ),
                );

                await _loadGroupOrders();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error clearing data: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createTestUsers() async {
    Navigator.of(context).pop(); // Close dialog first
    
    try {
      final testUsers = [
        {
          'uid': 'test_vendor_1',
          'name': 'Test Vendor Restaurant',
          'email': 'vendor@test.com',
          'role': 'vendor',
          'phone': '+60123456790',
          'address': 'Test Restaurant Address, KL',
        },
        {
          'uid': 'customer_sample_1',
          'name': 'Alice Test Customer',
          'email': 'alice@test.com',
          'role': 'customer',
          'phone': '+60123456791',
          'address': '123 Test Street, KL',
        },
        {
          'uid': 'customer_sample_2',
          'name': 'Bob Test Customer',
          'email': 'bob@test.com',
          'role': 'customer',
          'phone': '+60123456792',
          'address': '456 Another Street, KL',
        }
      ];

      final batch = FirebaseFirestore.instance.batch();
      for (var user in testUsers) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user['uid'] as String);
        batch.set(userRef, {
          ...user,
          'created_at': Timestamp.now(),
          'updated_at': Timestamp.now(),
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Test users created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error creating test users: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                      ? RefreshIndicator(
                          onRefresh: () async {
                            await _loadGroupOrders();
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 200),
                              Center(
                                child: Text(
                                  'No group orders found\nPull down to refresh',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _loadGroupOrders();
                          },
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: groupOrders.length,
                            itemBuilder: (context, index) {
                          final order = groupOrders[index];
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
                                        '${_formatTimestamp(order.scheduledTime)}',
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
                                        ElevatedButton.icon(
                                          onPressed: () => _navigateToLiveDelivery(order),
                                          icon: const Icon(
                                            Icons.navigation, 
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            'View Order',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
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
          ),
        ],
      ),
          // Positioned dev tools button above chat button
          Positioned(
            bottom: 90,
            right: 20,
            child: _buildDevToolsButton(),
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
