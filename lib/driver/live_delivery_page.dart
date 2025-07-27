import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/models.dart';
import '../services/chat_service.dart';
import '../services/route_service.dart';
import '../chat_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

class LiveDeliveryPage extends StatefulWidget {
  const LiveDeliveryPage({super.key});

  @override
  State<LiveDeliveryPage> createState() => _LiveDeliveryPageState();
}

class _LiveDeliveryPageState extends State<LiveDeliveryPage> {
  GroupOrder? groupOrder;
  List<Order> deliveries = [];
  List<LatLng> optimizedWaypoints = [];
  LatLng? vendorLocation;
  Map<String, dynamic>? vendorInfo;
  AppUser? currentUser;
  LatLng? driverLocation;
  String currentStatus = 'Heading to Vendor';
  int currentDeliveryIndex = 0; // Track which delivery we're on
  List<LatLng> routePoints = [];
  List<LatLng> currentRoutePoints = []; // Route from current point to next point only
  bool isLoading = false;
  int currentNavigationStep = 0; // 0: driver->vendor, 1: vendor->customer1, 2: customer1->customer2, etc.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeliveryData();
    });
  }

  void _loadDeliveryData() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      setState(() {
        // Parse groupOrder from Map to GroupOrder
        final groupOrderData = args['groupOrder'] as Map<String, dynamic>?;
        if (groupOrderData != null) {
          groupOrder = GroupOrder.fromFirestore(groupOrderData, groupOrderData['id'] ?? '');
        }
        
        // Parse deliveries from List<Map> to List<Order>
        final deliveriesData = args['deliveries'] as List<dynamic>? ?? [];
        deliveries = deliveriesData.map((data) {
          final orderMap = data as Map<String, dynamic>;
          return Order.fromFirestore(orderMap, orderMap['id'] ?? '');
        }).toList();
        
        optimizedWaypoints = List<LatLng>.from(args['optimizedWaypoints'] ?? []);
        vendorLocation = args['vendorLocation'];
        vendorInfo = args['vendorInfo'];
        currentUser = args['currentUser'];
        driverLocation = args['driverLocation'];
      });
      
      // Refresh delivery data from Firebase to get latest status
      _refreshDeliveryDataFromFirebase();
      
      // Generate route if waypoints are available
      if (optimizedWaypoints.isNotEmpty) {
        _generateCurrentStepRoute();
      }
    }
  }

  Future<void> _refreshDeliveryDataFromFirebase() async {
    if (groupOrder == null) return;
    
    try {
      // Get latest group order data
      final groupOrderDoc = await FirebaseFirestore.instance
          .collection('grouporders')
          .doc(groupOrder!.id)
          .get();
      
      if (groupOrderDoc.exists) {
        final updatedGroupOrder = GroupOrder.fromFirestore(
          groupOrderDoc.data()!,
          groupOrderDoc.id,
        );
        
        // Get latest individual orders data
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('group_id', isEqualTo: groupOrder!.id)
            .get();
        
        final updatedDeliveries = ordersSnapshot.docs.map((doc) {
          return Order.fromFirestore(doc.data(), doc.id);
        }).toList();
        
        setState(() {
          groupOrder = updatedGroupOrder;
          deliveries = updatedDeliveries;
          
          // Restore delivery state from Firebase if available
          currentDeliveryIndex = groupOrder!.currentDeliveryIndex ?? 0;
          currentNavigationStep = groupOrder!.currentNavigationStep ?? 0;
          
          // Determine current status based on saved state
          _restoreCurrentStatus();
        });
      }
    } catch (e) {
      print('Error refreshing delivery data: $e');
      // Fallback to original state restoration
      if (groupOrder != null) {
        setState(() {
          currentDeliveryIndex = groupOrder!.currentDeliveryIndex ?? 0;
          currentNavigationStep = groupOrder!.currentNavigationStep ?? 0;
          _restoreCurrentStatus();
        });
      }
    }
  }

  void _restoreCurrentStatus() {
    if (groupOrder == null) return;
    
    // Use the status from Firebase if it's already set and not default
    if (groupOrder!.status.isNotEmpty && 
        groupOrder!.status != 'pending' && 
        groupOrder!.status != 'assigned' &&
        groupOrder!.status != 'open') {
      currentStatus = groupOrder!.status;
      return;
    }
    
    // Otherwise, determine status based on navigation step and delivery index
    if (currentNavigationStep == 0) {
      currentStatus = 'Heading to Vendor';
    } else if (currentNavigationStep == 1) {
      // Check if orders are already picked up (have pickup_time or status = delivering)
      bool ordersPickedUp = deliveries.any((order) => 
          order.pickupTime != null || 
          order.status == 'delivering' || 
          order.status == 'delivered');
      
      if (ordersPickedUp) {
        currentStatus = 'Heading to Customer ${currentDeliveryIndex + 1}';
      } else {
        currentStatus = 'At Vendor - Picking Up';
      }
    } else if (currentNavigationStep > 1) {
      // Check if current delivery is completed
      if (currentDeliveryIndex < deliveries.length) {
        final currentOrder = deliveries[currentDeliveryIndex];
        if (currentOrder.status == 'delivered') {
          // If current order is delivered but we're still on this step, 
          // we're heading to next customer
          if (currentDeliveryIndex + 1 < deliveries.length) {
            currentStatus = 'Heading to Customer ${currentDeliveryIndex + 2}';
          } else {
            currentStatus = 'All Deliveries Complete';
          }
        } else {
          // Still delivering to current customer
          currentStatus = 'At Customer ${currentDeliveryIndex + 1} - Delivering';
        }
      } else {
        currentStatus = 'All Deliveries Complete';
      }
    } else {
      currentStatus = 'Heading to Vendor';
    }
  }

  Future<void> _generateCurrentStepRoute() async {
    if (optimizedWaypoints.isEmpty || driverLocation == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      LatLng currentPoint;
      LatLng nextPoint;

      // Determine current and next points based on navigation step
      if (currentNavigationStep == 0) {
        // Driver to vendor
        currentPoint = driverLocation!;
        nextPoint = vendorLocation ?? optimizedWaypoints[1]; // Vendor is typically second waypoint
      } else if (currentNavigationStep <= deliveries.length) {
        // Vendor to customer or customer to customer
        if (currentNavigationStep == 1) {
          // Vendor to first customer
          currentPoint = vendorLocation ?? optimizedWaypoints[1];
          nextPoint = optimizedWaypoints[currentNavigationStep + 1];
        } else {
          // Customer to customer
          currentPoint = optimizedWaypoints[currentNavigationStep];
          nextPoint = optimizedWaypoints[currentNavigationStep + 1];
        }
      } else {
        // All deliveries complete
        setState(() {
          currentRoutePoints = [];
          isLoading = false;
        });
        return;
      }

      // Get route between current point and next point
      await _getCurrentStepRoute(currentPoint, nextPoint);
    } catch (e) {
      print('Error generating current step route: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getCurrentStepRoute(LatLng start, LatLng end) async {
    final List<String> osrmServers = [
      'https://router.project-osrm.org',
      'https://routing.openstreetmap.de',
      'https://osrm.map.bf-ds.de',
    ];

    for (String server in osrmServers) {
      try {
        String coordinates = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';

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
              currentRoutePoints =
                  coordinates
                      .map<LatLng>(
                        (coord) => LatLng(
                          coord[1],
                          coord[0],
                        ), // OSRM returns [lon, lat]
                      )
                      .toList();
              isLoading = false;
            });

            print('Successfully got step route from OSRM server: $server');
            return;
          }
        }
      } catch (e) {
        print('Failed to get step route from $server: $e');
        continue;
      }
    }

    // Fallback: Create direct route
    _createDirectRoute(start, end);
  }

  void _createDirectRoute(LatLng start, LatLng end) {
    List<LatLng> routePointsList = [];
    
    routePointsList.add(start);
    
    // Create realistic curve between points
    final double latDiff = end.latitude - start.latitude;
    final double lngDiff = end.longitude - start.longitude;
    final double distance = RouteService.calculateDistance(start, end);

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

    setState(() {
      currentRoutePoints = routePointsList;
      isLoading = false;
    });
  }



  List<Polyline> _createCurrentStepRoute() {
    if (currentRoutePoints.isEmpty) return [];
    
    // Determine color based on current navigation step
    Color routeColor;
    if (currentNavigationStep == 0) {
      routeColor = Colors.blue; // Driver to vendor
    } else if (currentNavigationStep == 1) {
      routeColor = Colors.green; // Vendor to first customer
    } else {
      // Customer to customer - use different colors
      final List<Color> customerColors = [
        Colors.red, Colors.orange, Colors.purple, Colors.cyan,
        Colors.pink, Colors.amber, Colors.indigo, Colors.teal,
      ];
      routeColor = customerColors[(currentNavigationStep - 2) % customerColors.length];
    }
    
    return [
      Polyline(
        points: currentRoutePoints,
        strokeWidth: 5.0,
        color: routeColor,
      ),
    ];
  }

  void _updateDeliveryStatus() async {
    if (groupOrder == null) return;
    
    try {
      String newStatus = currentStatus; // Initialize with current status
      
      if (currentStatus == 'Heading to Vendor') {
        newStatus = 'At Vendor - Picking Up';
        // No navigation step change yet, still at vendor
      } else if (currentStatus == 'At Vendor - Picking Up') {
        newStatus = 'Heading to Customer ${currentDeliveryIndex + 1}';
        // Update all orders in this group to "delivering" status
        await _updateAllOrdersToDelivering();
        // Move to next navigation step (vendor to first customer)
        setState(() {
          currentNavigationStep = 1;
        });
        await _generateCurrentStepRoute();
      } else if (currentStatus.startsWith('Heading to Customer')) {
        newStatus = 'At Customer ${currentDeliveryIndex + 1} - Delivering';
        // No navigation step change yet, still at current customer
      } else if (currentStatus.startsWith('At Customer') && currentStatus.contains('Delivering')) {
        // Mark current customer's order as delivered
        await _markCurrentOrderAsDelivered();
        
        // Move to next delivery or complete
        if (currentDeliveryIndex + 1 < deliveries.length) {
          setState(() {
            currentDeliveryIndex++;
            currentNavigationStep++; // Move to next customer
          });
          newStatus = 'Heading to Customer ${currentDeliveryIndex + 1}';
          await _generateCurrentStepRoute();
        } else {
          newStatus = 'All Deliveries Complete';
          setState(() {
            currentRoutePoints = []; // Clear route
          });
          await _completeAllDeliveries();
          return;
        }
      }
      
      setState(() {
        currentStatus = newStatus;
      });
      
      // Update Firebase with current status
      await FirebaseFirestore.instance
          .collection('grouporders')
          .doc(groupOrder!.id)
          .update({
        'status': newStatus,
        'current_delivery_index': currentDeliveryIndex,
        'current_navigation_step': currentNavigationStep,
        'updated_at': Timestamp.now(),
      });
      
    } catch (e) {
      print('Error updating delivery status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateAllOrdersToDelivering() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Update all orders in this group to "delivering" status
      for (var delivery in deliveries) {
        if (delivery.id.isNotEmpty) {
          final orderRef = FirebaseFirestore.instance
              .collection('orders')
              .doc(delivery.id);
          
          batch.update(orderRef, {
            'status': 'delivering',
            'pickup_time': Timestamp.now(),
            'updated_at': Timestamp.now(),
          });
        }
      }
      
      await batch.commit();
      
      print('Updated ${deliveries.length} orders to delivering status');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${deliveries.length} orders marked as picked up and delivering'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error updating orders to delivering: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order statuses: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _markCurrentOrderAsDelivered() async {
    if (currentDeliveryIndex >= deliveries.length) return;
    
    try {
      final currentDelivery = deliveries[currentDeliveryIndex];
      if (currentDelivery.id.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(currentDelivery.id)
            .update({
          'status': 'delivered',
          'delivery_time': Timestamp.now(),
          'updated_at': Timestamp.now(),
        });
        
        print('Marked order ${currentDelivery.id} as delivered');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${currentDelivery.id} marked as delivered'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error marking order as delivered: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order status: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _completeAllDeliveries() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Update group order status to completed
      final groupOrderRef = FirebaseFirestore.instance
          .collection('grouporders')
          .doc(groupOrder!.id);
      
      batch.update(groupOrderRef, {
        'status': 'completed',
        'completed_at': Timestamp.now(),
        'updated_at': Timestamp.now(),
      });
      
      // Ensure all individual orders are marked as delivered (safety check)
      for (var delivery in deliveries) {
        if (delivery.id.isNotEmpty) {
          final orderRef = FirebaseFirestore.instance
              .collection('orders')
              .doc(delivery.id);
          
          batch.update(orderRef, {
            'status': 'delivered',
            'delivery_time': Timestamp.now(),
            'updated_at': Timestamp.now(),
          });
        }
      }
      
      await batch.commit();
      
      // Mark chat room as completed
      await ChatService.completeOrderChatRoom(groupOrder!.id);
      
      print('Completed group order ${groupOrder!.id} and all individual orders');
      
      // Show completion dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('🎉 All Deliveries Complete!'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Congratulations! All deliveries have been completed successfully.'),
                  const SizedBox(height: 16),
                  Text(
                    'Group Order ID: ${groupOrder!.id}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Total Deliveries: ${deliveries.length}'),
                  Text(
                    'Total Fee Earned: RM ${_calculateTotalFee().toStringAsFixed(2)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to driver home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Back to Home'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error completing deliveries: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing deliveries: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  double _calculateTotalFee() {
    return deliveries.fold(0.0, (sum, delivery) => 
        sum + delivery.deliveryFeeAsDouble);
  }

  String _getNextStatusButtonText() {
    if (currentStatus == 'Heading to Vendor') {
      return 'Mark: Arrived at Vendor';
    } else if (currentStatus == 'At Vendor - Picking Up') {
      return 'Mark: Order Picked Up';
    } else if (currentStatus.startsWith('Heading to Customer')) {
      return 'Mark: Arrived at Customer';
    } else if (currentStatus.startsWith('At Customer') && currentStatus.contains('Delivering')) {
      if (currentDeliveryIndex + 1 < deliveries.length) {
        return 'Mark: Delivered - Next Customer';
      } else {
        return 'Mark: Final Delivery Complete';
      }
    }
    
    return 'Update Status';
  }

  IconData _getStatusIcon() {
    if (currentStatus == 'Heading to Vendor' || currentStatus == 'At Vendor - Picking Up') {
      return Icons.store;
    } else if (currentStatus.startsWith('Heading to Customer')) {
      return Icons.delivery_dining;
    } else if (currentStatus.contains('Delivering')) {
      return Icons.home;
    } else if (currentStatus == 'All Deliveries Complete') {
      return Icons.check_circle;
    }
    return Icons.delivery_dining;
  }

  Color _getOrderStatusColor(int index) {
    if (index < currentDeliveryIndex) {
      return Colors.green; // Delivered
    } else if (index == currentDeliveryIndex) {
      if (currentStatus.contains('Delivering')) {
        return Colors.orange; // Currently delivering
      } else if (currentStatus.contains('Picking Up') || currentStatus.contains('Heading to Customer')) {
        return Colors.blue; // Picked up/delivering
      }
    }
    return Colors.grey; // Pending
  }

  String _getOrderStatusText(int index) {
    if (index < currentDeliveryIndex) {
      return 'DELIVERED';
    } else if (index == currentDeliveryIndex) {
      if (currentStatus.contains('Delivering')) {
        return 'DELIVERING';
      } else if (currentStatus.contains('Picking Up') || currentStatus.contains('Heading to Customer')) {
        return 'PICKED UP';
      }
    }
    return 'PENDING';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Delivery - Order ${groupOrder?.id ?? 'N/A'}'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          StreamBuilder<bool>(
            stream: _hasUnreadMessagesStream(),
            builder: (context, snapshot) {
              final hasUnread = snapshot.data ?? false;
              return Stack(
                children: [
                  IconButton(
                    onPressed: _openChatRoom,
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'Open Chat',
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: groupOrder == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Status Banner
                _buildStatusBanner(),
                
                // Navigation Step Indicator
                _buildNavigationStepIndicator(),
                
                // Map - 40% of screen
                Expanded(
                  flex: 4,
                  child: _buildMap(),
                ),
                
                // Delivery Details - 60% of screen
                Expanded(
                  flex: 6,
                  child: _buildDeliveryDetails(),
                ),
              ],
            ),
      floatingActionButton: StreamBuilder<bool>(
        stream: _hasUnreadMessagesStream(),
        builder: (context, snapshot) {
          final hasUnread = snapshot.data ?? false;
          return Stack(
            children: [
              FloatingActionButton(
                onPressed: _openChatRoom,
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                tooltip: 'Open Chat',
                child: const Icon(Icons.chat),
              ),
              if (hasUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(),
              color: Colors.green[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Delivery ${currentDeliveryIndex + 1} of ${deliveries.length}',
                  style: TextStyle(
                    color: Colors.green[100],
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationStepIndicator() {
    if (optimizedWaypoints.isEmpty) return const SizedBox.shrink();
    
    String fromText = '';
    String toText = '';
    IconData fromIcon = Icons.local_shipping;
    IconData toIcon = Icons.location_on;
    Color indicatorColor = Colors.blue;
    
    if (currentNavigationStep == 0) {
      fromText = 'Driver';
      toText = 'Vendor';
      fromIcon = Icons.local_shipping;
      toIcon = Icons.store;
      indicatorColor = Colors.blue;
    } else if (currentNavigationStep == 1) {
      fromText = 'Vendor';
      toText = 'Customer 1';
      fromIcon = Icons.store;
      toIcon = Icons.home;
      indicatorColor = Colors.green;
    } else if (currentNavigationStep <= deliveries.length) {
      fromText = 'Customer ${currentNavigationStep - 1}';
      toText = 'Customer $currentNavigationStep';
      fromIcon = Icons.home;
      toIcon = Icons.home;
      final List<Color> customerColors = [
        Colors.red, Colors.orange, Colors.purple, Colors.cyan,
        Colors.pink, Colors.amber, Colors.indigo, Colors.teal,
      ];
      indicatorColor = customerColors[(currentNavigationStep - 2) % customerColors.length];
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          // From location
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              fromIcon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fromText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: indicatorColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Navigation arrow
          Icon(
            Icons.arrow_forward,
            color: indicatorColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          // To location
          Expanded(
            child: Text(
              toText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: indicatorColor,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              toIcon,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : FlutterMap(
                options: MapOptions(
                  initialCenter: driverLocation ?? LatLng(3.139, 101.6869),
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.mealmommy',
                  ),
                  // Route polylines - show only current step route
                  if (currentRoutePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: _createCurrentStepRoute(),
                    ),
                  MarkerLayer(
                    markers: [
                      // Driver location
                      if (driverLocation != null)
                        Marker(
                          point: driverLocation!,
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                      // Vendor location
                      if (vendorLocation != null)
                        Marker(
                          point: vendorLocation!,
                          child: const Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.store,
                                color: Colors.blue,
                                size: 40,
                              ),
                              Positioned(
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
                      // Customer delivery locations
                      ...deliveries.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final delivery = entry.value;
                        final double lat = delivery.latitude ?? 0.0;
                        final double lng = delivery.longitude ?? 0.0;
                        
                        if (lat == 0.0 || lng == 0.0) return const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
                        
                        final List<Color> markerColors = [
                          Colors.red, Colors.orange, Colors.purple, Colors.cyan,
                          Colors.pink, Colors.amber, Colors.indigo, Colors.teal,
                        ];
                        
                        return Marker(
                          point: LatLng(lat, lng),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.location_on,
                                color: markerColors[index % markerColors.length],
                                size: 35,
                              ),
                              Positioned(
                                top: 8,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Vendor Information Card
          if (vendorInfo != null) _buildVendorCard(),
          
          const SizedBox(height: 8),
          
          // Deliveries List
          Expanded(
            child: ListView.builder(
              itemCount: deliveries.length,
              itemBuilder: (context, index) {
                final delivery = deliveries[index];
                final bool isCurrentDelivery = index == currentDeliveryIndex;
                final bool isCompleted = index < currentDeliveryIndex;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCurrentDelivery 
                        ? Colors.blue[50] 
                        : isCompleted 
                            ? Colors.green[50] 
                            : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrentDelivery 
                          ? Colors.blue 
                          : isCompleted 
                              ? Colors.green 
                              : Colors.grey[300]!,
                      width: isCurrentDelivery || isCompleted ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted 
                                  ? Colors.green 
                                  : isCurrentDelivery 
                                      ? Colors.blue 
                                      : Colors.grey[400],
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Order ID: ${delivery.id}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getOrderStatusColor(index),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getOrderStatusText(index),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  delivery.customerName ?? 'Customer Name',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isCompleted)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            )
                          else if (isCurrentDelivery)
                            const Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 24,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Delivery Address
                      Row(
                        children: [
                          Icon(Icons.home, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              delivery.deliveryAddress.isNotEmpty ? delivery.deliveryAddress : 'Address not available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Phone and Fee
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text(
                              delivery.customerPhone ?? 'N/A',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Fee: RM ${delivery.deliveryFee}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      // Action buttons for current delivery
                      if (isCurrentDelivery) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _callCustomer(delivery.customerPhone),
                                icon: const Icon(Icons.phone, size: 16),
                                label: const Text(
                                  'Call',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _openChatRoom,
                                icon: const Icon(Icons.chat, size: 16),
                                label: const Text(
                                  'Chat',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openNavigationToCustomer(delivery),
                                icon: const Icon(Icons.navigation, size: 16),
                                label: const Text(
                                  'Navigate',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Status Update Button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _updateDeliveryStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _getNextStatusButtonText(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.store, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendorInfo!['name'] ?? 'Vendor',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  vendorInfo!['address'] ?? 'Vendor Address',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _callVendor(),
                icon: const Icon(Icons.phone, size: 16),
                label: const Text(
                  'Call',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _openChatRoom,
                icon: const Icon(Icons.chat, size: 16),
                label: const Text(
                  'Chat',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _callCustomer(String? phoneNumber) {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling $phoneNumber...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _callVendor() {
    final vendorPhone = vendorInfo?['phone_number'];
    if (vendorPhone != null && vendorPhone.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling vendor: $vendorPhone...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor phone number not available'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openNavigationToCustomer(Order delivery) {
    final lat = delivery.latitude;
    final lng = delivery.longitude;
    
    if (lat != null && lng != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening navigation to ${delivery.customerName ?? 'customer'}...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      // Here you would integrate with actual navigation apps like Google Maps
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer location not available'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Stream<bool> _hasUnreadMessagesStream() {
    if (currentUser == null) {
      return Stream.value(false);
    }
    
    return ChatService.hasUnreadMessages(currentUser!.uid).asStream();
  }

  void _openChatRoom() async {
    if (groupOrder == null || currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open chat - order or user data not available'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      print('🔍 Looking for chat room for group order: ${groupOrder!.id}');
      
      // Get the chat room for this group order
      final chatRooms = await ChatService.getUserChatRooms(currentUser!.uid);
      
      print('📋 Found ${chatRooms.length} chat rooms for user: ${currentUser!.uid}');
      
      // Find the chat room for this specific order
      Map<String, dynamic>? orderChatRoom;
      for (var chatRoom in chatRooms) {
        print('🏠 Checking chat room: ${chatRoom['id']} with group_id: ${chatRoom['group_id']}');
        
        // Check the correct field name used by ChatService
        if (chatRoom['group_id'] == groupOrder!.id) {
          orderChatRoom = chatRoom;
          print('✅ Found matching chat room: ${chatRoom['id']}');
          break;
        }
      }

      // Close loading indicator
      if (mounted) Navigator.of(context).pop();

      if (orderChatRoom != null && mounted) {
        print('🚀 Navigating to chat room: ${orderChatRoom['id']}');
        
        // Navigate to the specific chat room
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              chatRoomId: orderChatRoom!['id'],
              currentUserId: currentUser!.uid,
            ),
          ),
        );
        
        print('⬅️ Returned from chat with result: $result');
      } else {
        print('❌ No chat room found, attempting to create one...');
        
        // Attempt to create a new chat room
        await _createChatRoomForOrder();
      }
    } catch (e) {
      // Close loading indicator if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      print('❌ Error opening chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _openChatRoom,
            ),
          ),
        );
      }
    }
  }

  Future<void> _createChatRoomForOrder() async {
    if (groupOrder == null || currentUser == null) return;

    try {
      // Show loading for chat room creation
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Creating chat room...'),
              ],
            ),
          ),
        );
      }

      // Get vendor ID from deliveries or vendorInfo
      String vendorId = '';
      if (deliveries.isNotEmpty && deliveries[0].vendorId.isNotEmpty) {
        vendorId = deliveries[0].vendorId;
      } else if (vendorInfo != null && vendorInfo!['id'] != null) {
        vendorId = vendorInfo!['id'];
      }

      // Get customer IDs from deliveries
      List<String> customerIds = [];
      for (var delivery in deliveries) {
        if (delivery.customerId.isNotEmpty) {
          customerIds.add(delivery.customerId);
        }
      }

      print('🔨 Creating chat room with:');
      print('   Group Order ID: ${groupOrder!.id}');
      print('   Driver ID: ${currentUser!.uid}');
      print('   Vendor ID: $vendorId');
      print('   Customer IDs: $customerIds');

      // Create the chat room
      final chatRoomId = await ChatService.createOrderChatRoom(
        groupOrderId: groupOrder!.id,
        driverId: currentUser!.uid,
        vendorId: vendorId,
        customerIds: customerIds,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (chatRoomId != null && mounted) {
        print('✅ Chat room created successfully: $chatRoomId');
        
        // Navigate to the newly created chat room
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              chatRoomId: chatRoomId,
              currentUserId: currentUser!.uid,
            ),
          ),
        );
        
        print('⬅️ Returned from new chat with result: $result');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create chat room'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      print('❌ Error creating chat room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating chat room: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
